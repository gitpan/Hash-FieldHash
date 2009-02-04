/*
     a 0.03 candidate. uses refaddr as the identifiers (H::U::F compatible)
 */

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#define PACKAGE "Hash::FieldHash"
#define OBJECT_REGISTRY_KEY PACKAGE "::" "::OBJECT_REGISTRY"

#define INVALID_OBJECT "Invalid object \"%"SVf"\" as a fieldhash key"

/* the global object registry */
#define MY_CXT_KEY PACKAGE "::_guts" XS_VERSION
typedef struct {
    HV* object_registry;
} my_cxt_t;
START_MY_CXT
#define OBJECT_REGISTRY (MY_CXT.object_registry)

MGVTBL fieldhash_key_vtbl;
#define fieldhash_key_mg(sv) my_mg_find_by_vtbl(aTHX_ sv, &fieldhash_key_vtbl)


static MAGIC*
my_mg_find_by_vtbl(pTHX_ SV* const sv, const MGVTBL* const vtbl){
	MAGIC* mg;

	assert(sv != NULL);
	if(SvTYPE(sv) < SVt_PVMG) return NULL;

	for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
		if(mg->mg_virtual == vtbl){
			break;
		}
	}
	return mg;
}

static I32
fieldhash_watch(pTHX_ IV const action, SV* const fieldhash);
struct ufuncs fieldhash_ufuncs = {
	fieldhash_watch, /* uf_val */
	NULL,            /* uf_set */
	0,               /* uf_index */
};

#if PERL_VERSION >= 10 /* >= 5.10.0 */

#define fieldhash_mg(sv) hf_fieldhash_mg(aTHX_ sv)
static MAGIC*
hf_fieldhash_mg(pTHX_ SV* const sv){
	MAGIC* mg;

	assert(sv != NULL);
	for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
		if(mg->mg_type == PERL_MAGIC_uvar
			&& ((struct ufuncs*)(mg->mg_ptr)) == &fieldhash_ufuncs){
			break;
		}
	}
	return mg;
}

#else /* PERL_VERSION < 5.10 */
#include "compat58.h"
#endif


static SV*
fieldhash_av_find(pTHX_ AV* const av, SV* const sv){
	SV** const ary = AvARRAY(av);
	I32  const len = AvFILLp(av)+1;
	I32 i;
	for(i = 0; i < len; i++){
		if(ary[i] == sv){
			return sv;
		}
	}
	return NULL;
}

/*
    defined actions (in 5.10.0) are:
       HV_FETCH_ISSTORE  = 0x04
       HV_FETCH_ISEXISTS = 0x08
       HV_FETCH_LVALUE   = 0x10
       HV_FETCH_JUST_SV  = 0x20
       HV_DELETE         = 0x40
 */
#define UPDATING_ACTION(a) (a & (HV_FETCH_ISSTORE | HV_FETCH_LVALUE))

static I32
fieldhash_watch(pTHX_ IV const action, SV* const fieldhash){
	MAGIC* const mg = fieldhash_mg(fieldhash);
	SV* key;
	SV* obj;
	MAGIC* key_mg;
	AV* reg;         /* field registry */

	assert(mg != NULL);

	key = mg->mg_obj;
	if(!SvROK(key)){ /* maybe it's an object address */
		if(!UPDATING_ACTION(action)){
			if(!looks_like_number(key)){ /* maybe too simple, but fast */
				Perl_croak(aTHX_ INVALID_OBJECT, key);
			}
			return 0;
		}
		else{
			dMY_CXT;
			HE* const he = hv_fetch_ent(OBJECT_REGISTRY, key, 0, 0U);

			if(!he){
				Perl_croak(aTHX_ INVALID_OBJECT, key);
			}

			key = HeVAL(he);
			assert(SvROK(key));
		}
	}

	obj = SvRV(key);
	assert(SvREFCNT(obj) != 0);

	key_mg = fieldhash_key_mg(obj);
	if(!key_mg){ /* first access */
		SV* const obj_id = newSVpvf("%"UVuf, PTR2UV(obj));

		mg->mg_obj = obj_id; /* key replacement */

		if(!UPDATING_ACTION(action)){
			sv_2mortal(obj_id);
			return 0;
		}

		reg = newAV();

		key_mg = sv_magicext(
			obj,
			(SV*)reg,
			PERL_MAGIC_ext,
			&fieldhash_key_vtbl,
			(char*)obj_id,
			HEf_SVKEY
		);
		SvREFCNT_dec(obj_id); /* refcnt++ in sv_magicext() */
		SvREFCNT_dec(reg);    /* refcnt++ in sv_magicext() */

		{
			dMY_CXT;
			SV* const ref = newRV_inc(obj);
			sv_rvweaken(ref);
			hv_store_ent(OBJECT_REGISTRY, obj_id, ref, 0U);
		}
	}
	else{
		/* key_mg->mg_ptr is obj_id */
		mg->mg_obj = (SV*)key_mg->mg_ptr; /* key replacement */
		assert(SvOK(mg->mg_obj));

		if(!UPDATING_ACTION(action)){
			return 0;
		}

		reg = (AV*)key_mg->mg_obj;
		assert(SvTYPE(reg) == SVt_PVAV);
	}

	if(!fieldhash_av_find(aTHX_ reg, (SV*)fieldhash)){
		av_push(reg, (SV*)fieldhash);
		SvREFCNT_inc_simple_void_NN(fieldhash);
	}

	return 0;
}

static int
fieldhash_key_free(pTHX_ SV* const sv, MAGIC* const mg){
	PERL_UNUSED_ARG(sv);

	/*
		Do nothing during global destruction, because
		some data may already be released.
	*/
	if(!PL_dirty){
		AV* const reg    = (AV*)mg->mg_obj; /* field registry */
		SV* const obj_id = (SV*)mg->mg_ptr;
		I32 const len    = AvFILLp(reg)+1;
		I32 i;
		dMY_CXT;

		//warn("key_free(sv=%"UVuf", mg=%"UVuf")", PTR2UV(sv), PTR2UV(mg));

		assert(SvTYPE(reg) == SVt_PVAV);
		assert(SvOK(obj_id));

		hv_delete_ent(OBJECT_REGISTRY, obj_id, G_DISCARD, 0U);

		for(i = 0; i < len; i++){
			HV* const fieldhash = (HV*)AvARRAY(reg)[i];

			/* NOTE: Don't use G_DISCARD,
				 because it may cause a double-free problem (t/11_panic_malloc.t).
			*/
			hv_delete_ent(fieldhash, obj_id, 0, 0U);
		}

	}

	return 0;
}

#ifdef USE_ITHREADS
/* fieldhash cloning in creating threads */
static void
fieldhash_clone(pTHX){
	HV* const old_object_registry = get_hv(OBJECT_REGISTRY_KEY, GV_ADDMULTI);
	HV* const new_object_registry = newHV();
	HE* he;
	MY_CXT_CLONE;

	OBJECT_REGISTRY = new_object_registry;

	hv_iterinit(old_object_registry);
	/* for each object */
	while((he = hv_iternext(old_object_registry))){
		SV* const obj_ref   = HeVAL(he);
		SV* const obj       = SvRV(obj_ref);
		MAGIC* const key_mg = fieldhash_key_mg(obj);
		AV* reg; /* field registry */
		SV* new_id;
		SV* old_id;
		I32 len;
		I32 i;

		assert(key_mg);

		old_id  = (SV*)key_mg->mg_ptr;
		new_id  = newSVpvf("%"UVuf, PTR2UV(obj));

		key_mg->mg_ptr = (char*)new_id;

		hv_store_ent(new_object_registry, new_id, obj_ref, 0U);
		SvREFCNT_inc_simple_void_NN(obj_ref);

		reg = (AV*)key_mg->mg_obj;
		assert(SvTYPE(reg) == SVt_PVAV);

		len = AvFILLp(reg)+1;
		for(i = 0; i < len; i++){
			HV* const fieldhash    = (HV*)AvARRAY(reg)[i];
			SV* sv;

			assert(SvTYPE(fieldhash) == SVt_PVHV);

			if((sv = hv_delete_ent(fieldhash, old_id, 0, 0U))){
				hv_store_ent(fieldhash, new_id, sv, 0U);
				SvREFCNT_inc_simple_void_NN(sv);
			}
		}

		SvREFCNT_dec(old_id);
	}

	/*
		*OBJECT_REGISTRY_KEY = \%new_object_registry;
	*/
	sv_setsv_mg(
		(SV*)gv_fetchpvs(OBJECT_REGISTRY_KEY, GV_ADD, SVt_PVHV),
		sv_2mortal(newRV_noinc((SV*)new_object_registry))
	);
}
#endif /* !USE_ITHREADS */

MODULE = Hash::FieldHash	PACKAGE = Hash::FieldHash

PROTOTYPES: DISABLE

BOOT:
{
	MY_CXT_INIT;
	OBJECT_REGISTRY = get_hv(OBJECT_REGISTRY_KEY, GV_ADDMULTI);
	fieldhash_key_vtbl.svt_free = fieldhash_key_free;
}

#ifdef USE_ITHREADS

void
CLONE(const char* klass)
CODE:
	if(strEQ(klass, PACKAGE)){
		fieldhash_clone(aTHX);
	}

#endif

#if PERL_VERSION >= 10 /* >= 5.10.0 */

void
fieldhash(HV* hash)
PROTOTYPE: \%
CODE:
	if(!fieldhash_mg((SV*)hash)){
		hv_clear(hash);
		sv_magic((SV*)hash,
			NULL,                      /* mg_obj */
			PERL_MAGIC_uvar,           /* mg_type */
			(char*)&fieldhash_ufuncs,  /* mg_ptr as the ufuncs table */
			0                          /* mg_len (0 indicates static data) */
		);
	}

#else /* < 5.10.0 */

INCLUDE: compat58.xsi

#endif

