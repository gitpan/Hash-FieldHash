#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"

#define PACKAGE "Hash::FieldHash"
#define OBJECT_REGISTRY_KEY PACKAGE "::" "::OBJECT_REGISTRY"

#define INVALID_OBJECT "Invalid object \"%"SVf"\" as a fieldhash key"

#define MY_CXT_KEY PACKAGE "::_guts" XS_VERSION
typedef struct {
    AV* object_registry; /* the global object registry */
    I32 last_id;         /* the last allocated id */
    AV* id_pool;         /* the released ids list */
} my_cxt_t;
START_MY_CXT
#define ObjectRegistry (MY_CXT.object_registry)
#define LastId         (MY_CXT.last_id)
#define IdPool         (MY_CXT.id_pool)

static I32 fieldhash_watch(pTHX_ IV const action, SV* const fieldhash);
static const struct ufuncs fieldhash_ufuncs = {
	fieldhash_watch, /* uf_val */
	NULL,            /* uf_set */
	0,               /* uf_index */
};


static int fieldhash_key_free(pTHX_ SV* const sv, MAGIC* const mg);
static MGVTBL fieldhash_key_vtbl = {
	NULL, /* get */
	NULL, /* set */
	NULL, /* len */
	NULL, /* clear */
	fieldhash_key_free,
	NULL, /* copy */
	NULL, /* dup */
#ifdef MGf_LOCAL
	NULL, /* local */
#endif
};

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

#if PERL_BCDVERSION >= 0x5010000 /* >= 5.10.0 */

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

#else /* PERL_BCDVERSION < 0x5010000 (5.10.0) */
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
#define HF_CREATE_KEY(a) (a & (HV_FETCH_ISSTORE | HV_FETCH_LVALUE))

static I32
fieldhash_watch(pTHX_ IV const action, SV* const fieldhash){
	MAGIC* const mg = fieldhash_mg(fieldhash);
	SV* obj_ref;
	SV* obj;
	MAGIC* key_mg;
	AV* reg;         /* field registry */

	assert(mg != NULL);

	obj_ref = mg->mg_obj;
	if(!SvROK(obj_ref)){ /* it's ok if an object ID */
		if(!looks_like_number(obj_ref)){ /* looks like an ID? */
			Perl_croak(aTHX_ INVALID_OBJECT, obj_ref);
		}

		if(!HF_CREATE_KEY(action)){ /* fetch, exists, delete */
			return 0;
		}
		else{ /* store, lvalue fetch */
			dMY_CXT;
			SV** const svp = av_fetch(ObjectRegistry, SvIV(obj_ref), FALSE);

			if(!svp){
				Perl_croak(aTHX_ INVALID_OBJECT, obj_ref);
			}

			obj_ref = *svp;
			assert(SvROK(obj_ref));
		}
	}

	obj = SvRV(obj_ref);
	assert(SvREFCNT(obj) != 0);

	key_mg = fieldhash_key_mg(obj);
	if(!key_mg){ /* first access */
		if(!HF_CREATE_KEY(action)){ /* fetch, exists, delete */
			mg->mg_obj = &PL_sv_no; /* anything that is not a registered ID */
			return 0;
		}
		else{ /* store, lvalue fetch */
			dMY_CXT;
			SV* const obj_id = AvFILLp(IdPool) >= 0 ? av_pop(IdPool) : newSViv(++LastId);
			SV* const obj_weakref = sv_rvweaken(newRV_inc(obj));

			assert(obj_id != NULL);
			av_store(ObjectRegistry, SvIVX(obj_id), obj_weakref);

			mg->mg_obj = obj_id; /* key replacement */

			reg = newAV(); /* field registry for obj */

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
		}
	}
	else{
		/* key_mg->mg_ptr is obj_id */
		assert(SvIOK((SV*)key_mg->mg_ptr));
		mg->mg_obj = (SV*)key_mg->mg_ptr; /* key replacement */

		if(!HF_CREATE_KEY(action)){
			return 0;
		}

		reg = (AV*)key_mg->mg_obj;
		assert(SvTYPE(reg) == SVt_PVAV);
	}

	/* add a new fieldhash to the field registry if needed */
	if(!fieldhash_av_find(aTHX_ reg, (SV*)fieldhash)){
		av_push(reg, (SV*)SvREFCNT_inc_simple_NN(fieldhash));
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
		dMY_CXT;
		AV* const reg    = (AV*)mg->mg_obj; /* field registry */
		SV* const obj_id = (SV*)mg->mg_ptr;
		I32 const len    = AvFILLp(reg)+1;
		I32 i;

		//warn("key_free(sv=%"UVuf", mg=%"UVuf")", PTR2UV(sv), PTR2UV(mg));

		assert(SvTYPE(reg) == SVt_PVAV);
		assert(SvIOK(obj_id));

		av_push(IdPool, SvREFCNT_inc_simple_NN(obj_id));
		av_delete(ObjectRegistry, SvIVX(obj_id), G_DISCARD);

		/* delete $fieldhash{$obj} for each fieldhash */
		for(i = 0; i < len; i++){
			HV* const fieldhash = (HV*)AvARRAY(reg)[i];

			/* NOTE: Don't use G_DISCARD, because it may cause
			         a double-free problem (t/11_panic_malloc.t).
			*/
			hv_delete_ent(fieldhash, obj_id, 0, 0U);
		}
	}

	return 0;
}

MODULE = Hash::FieldHash	PACKAGE = Hash::FieldHash

PROTOTYPES: DISABLE

BOOT:
{
	MY_CXT_INIT;
	ObjectRegistry = get_av(OBJECT_REGISTRY_KEY, GV_ADDMULTI);
	LastId         = 0;
	IdPool         = newAV();
}

#ifdef USE_ITHREADS

void
CLONE(const char* klass)
CODE:
	if(strEQ(klass, PACKAGE)){
		MY_CXT_CLONE;

		ObjectRegistry = get_av(OBJECT_REGISTRY_KEY, GV_ADDMULTI);
		IdPool         = av_make(AvFILLp(IdPool)+1, AvARRAY(IdPool));
	}

#endif

#if PERL_BCDVERSION >= 0x5010000

void
fieldhash(HV* hash)
PROTOTYPE: \%
CODE:
	if(!fieldhash_mg((SV*)hash)){
		hv_clear(hash);
		sv_magic((SV*)hash,
			NULL,                           /* mg_obj */
			PERL_MAGIC_uvar,                /* mg_type */
			(const char*)&fieldhash_ufuncs, /* mg_ptr as the ufuncs table */
			0                               /* mg_len (0 indicates static data) */
		);
	}

#else /* < 5.10.0 */

INCLUDE: compat58.xsi

#endif
