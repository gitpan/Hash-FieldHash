#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#define PACKAGE "Hash::FieldHash"
#define OBJECT_REGISTRY_KEY PACKAGE "::" "::OBJECT_REGISTRY"


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
	MAGIC* key_mg;
	HV* reg;
	SV* obj = NULL;

	assert(mg != NULL);

	if(!SvROK(mg->mg_obj)){ /* maybe it's an object address */
		if(!UPDATING_ACTION(action)){
			if(!looks_like_number(mg->mg_obj)){
				Perl_croak(aTHX_ "Invalid object \"%"SVf"\" as a fieldhash key", mg->mg_obj);
			}
			return 0;
		}
		else{
			dMY_CXT;
			HE* const he = hv_fetch_ent(OBJECT_REGISTRY, mg->mg_obj, 0, 0U);

			if(!he){
				Perl_croak(aTHX_ "Invalid object \"%"SVf"\" as a fieldhash key", mg->mg_obj);
			}

			obj = SvRV( HeVAL(he) );
			assert(SvREFCNT(obj) != 0);
		}
	}
	else{
		obj = SvRV(mg->mg_obj);
	}

	key_mg = fieldhash_key_mg(obj);
	if(!key_mg){ /* first access */
		SV* const obj_id = newSVpvf("%"UVuf, PTR2UV(obj));

		mg->mg_obj = obj_id; /* key replacement */

		if(!UPDATING_ACTION(action)){
			sv_2mortal(obj_id);
			return 0;
		}

		reg = newHV();

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

		reg = (HV*)key_mg->mg_obj;
		assert(SvTYPE(reg) == SVt_PVHV);
	}

	{
		UV const fieldhash_id = PTR2UV(fieldhash);

		if(!hv_exists(reg, (const char*)&fieldhash_id, sizeof(fieldhash_id))){
			hv_store(reg, (const char*)&fieldhash_id, sizeof(fieldhash_id), fieldhash, 0U);
			SvREFCNT_inc_simple_void_NN(fieldhash);
		}
	}

	return 0;
}

static int
fieldhash_key_free(pTHX_ SV* const sv, MAGIC* const mg){
	PERL_UNUSED_ARG(sv);

	/*
		Do nothing during global destruction.
		Some data may already be released.
	*/
	if(!PL_dirty){
		HV* const reg    = (HV*)mg->mg_obj;
		SV* const obj_id = (SV*)mg->mg_ptr;
		HE* he;
		dMY_CXT;

		//warn("key_free(sv=%"UVuf", mg=%"UVuf")", PTR2UV(sv), PTR2UV(mg));

		assert(SvTYPE(reg) == SVt_PVHV);
		assert(SvOK(obj_id));

		hv_delete_ent(OBJECT_REGISTRY, obj_id, G_DISCARD, 0U);

		hv_iterinit(reg);
		while((he = hv_iternext(reg))){
			HV* const fieldhash = (HV*)HeVAL(he);

			/* NOTE: G_DISCARD may cause a double-free problem (t/11_panic_malloc.t) */
			hv_delete_ent(fieldhash, obj_id, 0, 0U); /* lazy destruction */
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
		SV* const obj_ref = HeVAL(he);
		SV* const obj     = SvRV(obj_ref);
		HV* new_reg;
		SV* new_id;
		MAGIC* key_mg;
		HV* old_reg;
		SV* old_id;
		HE* he;

		assert(obj != NULL);

		key_mg  = fieldhash_key_mg(obj);
		assert(key_mg);

		old_reg = (HV*)key_mg->mg_obj;
		old_id  = (SV*)key_mg->mg_ptr;

		new_reg = newHV();
		new_id  = newSVpvf("%"UVuf, PTR2UV(obj));

		key_mg->mg_obj = (SV*)new_reg;
		key_mg->mg_ptr = (char*)new_id;

		hv_store_ent(new_object_registry, new_id, obj_ref, 0U);
		SvREFCNT_inc_simple_void_NN(obj_ref);

		assert(SvTYPE(old_reg) == SVt_PVHV);
		hv_iterinit(old_reg);
		/* for each fieldhash */
		while((he = hv_iternext(old_reg))){
			HV* const fieldhash    = (HV*)HeVAL(he);
			UV  const fieldhash_id = PTR2UV(fieldhash);
			SV* sv;

			assert(SvTYPE(fieldhash) == SVt_PVHV);
			hv_store(new_reg, (const char*)&fieldhash_id, sizeof(fieldhash_id),
				(SV*)fieldhash, 0U);
			SvREFCNT_inc_simple_void_NN(fieldhash);

			if((sv = hv_delete_ent(fieldhash, old_id, 0, 0U))){
				hv_store_ent(fieldhash, new_id, sv, 0U);
				SvREFCNT_inc_simple_void_NN(sv);
			}
		}

		SvREFCNT_dec(old_reg);
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


#if PERL_VERSION >= 10

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

