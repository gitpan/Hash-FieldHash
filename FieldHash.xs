#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"
#include "mgx.h"
#if PERL_BCDVERSION < 0x5010000
#include "compat58.h"
#endif

#define NV2SVPTR(nv) NUM2PTR(SV*, (nv))

#define PACKAGE "Hash::FieldHash"
#define OBJECT_REGISTRY_KEY PACKAGE "::" "::OBJECT_REGISTRY"

#define INVALID_OBJECT "Invalid object \"%"SVf"\" as a fieldhash key"

#define MY_CXT_KEY PACKAGE "::_guts" XS_VERSION
typedef struct {
    AV* object_registry; /* the global object registry */
    I32 last_id;         /* the last allocated id */
    SV* free_id;         /* the top of the linked list */
} my_cxt_t;
START_MY_CXT
#define ObjectRegistry (MY_CXT.object_registry)
#define LastId         (MY_CXT.last_id)
#define FreeId         (MY_CXT.free_id)

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

#define fieldhash_key_mg(sv) MgFind(sv, &fieldhash_key_vtbl)

#if PERL_BCDVERSION >= 0x5010000 /* >= 5.10.0 */
static I32 fieldhash_watch(pTHX_ IV const action, SV* const fieldhash);
static struct ufuncs fieldhash_ufuncs = {
	fieldhash_watch, /* uf_val */
	NULL,            /* uf_set */
	0,               /* uf_index */
};

#define fieldhash_mg(sv) hf_fieldhash_mg(aTHX_ sv)
static MAGIC*
hf_fieldhash_mg(pTHX_ SV* const sv){
	MAGIC* mg;

	assert(sv != NULL);
	for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
		if(((struct ufuncs*)mg->mg_ptr) == &fieldhash_ufuncs){
			break;
		}
	}
	return mg;
}
#endif /* PERL_BCDVERSION < 0x5010000 (5.10.0) */

static SV*
hf_new_id(pTHX_ pMY_CXT){
	SV* obj_id;
	if(!FreeId){
		obj_id = newSV_type(SVt_PVNV);
		sv_setiv(obj_id, ++LastId);
	}
	else{
		obj_id = FreeId;
		FreeId = NV2SVPTR(SvNVX(obj_id)); /* next node */
		SvNV_set(obj_id, 0.0);

		assert(SvIOK(obj_id));
	}
	return obj_id;
}

static void
hf_free_id(pTHX_ pMY_CXT_ SV* const obj_id){
	assert(SvTYPE(obj_id) >= SVt_PVNV);

	SvNV_set(obj_id, PTR2NV(FreeId));
	FreeId = obj_id;
}

static SV*
hf_av_find(pTHX_ AV* const av, SV* const sv){
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
	const MAGIC* key_mg;
	AV* reg;         /* field registry */

	assert(mg != NULL);

	obj_ref = mg->mg_obj; /* the given hash key */

	if(!SvROK(obj_ref)){ /* it can be an object ID */
		if(!looks_like_number(obj_ref)){ /* looks like an ID? */
			Perl_croak(aTHX_ INVALID_OBJECT, obj_ref);
		}

		if(!HF_CREATE_KEY(action)){ /* fetch, exists, delete */
			return 0;
		}
		else{ /* store, lvalue fetch */
			dMY_CXT;
			SV** const svp = av_fetch(ObjectRegistry, (I32)SvIV(obj_ref), FALSE);

			if(!svp){
				Perl_croak(aTHX_ INVALID_OBJECT, obj_ref);
			}

			/* retrieve object from ID */
			obj_ref = *svp;
			assert(SvROK(obj_ref));
		}
	}

	obj = SvRV(obj_ref);
	assert(SvREFCNT(obj) != 0);

	key_mg = fieldhash_key_mg(obj);
	if(!key_mg){ /* first access */
		if(!HF_CREATE_KEY(action)){ /* fetch, exists, delete */
			/* replace the key with an arbitrary sv that is not a registered ID */
			mg->mg_obj = &PL_sv_no;
			return 0;
		}
		else{ /* store, lvalue fetch */
			dMY_CXT;
			SV* const obj_id      = hf_new_id(aTHX_ aMY_CXT);
			SV* const obj_weakref = sv_rvweaken(newRV_inc(obj));

			av_store(ObjectRegistry, (I32)SvIVX(obj_id), obj_weakref);

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

			/* no need to SvREFCNT_dec(obj_id) */
			SvREFCNT_dec(reg);    /* refcnt++ in sv_magicext() */
		}
	}
	else{
		/* key_mg->mg_ptr is obj_id */
		mg->mg_obj = (SV*)key_mg->mg_ptr; /* key replacement */

		if(!HF_CREATE_KEY(action)){
			return 0;
		}

		reg = (AV*)key_mg->mg_obj;
	}
	assert(SvTYPE(reg) == SVt_PVAV);

	/* add a new fieldhash to the field registry if needed */
	if(!hf_av_find(aTHX_ reg, (SV*)fieldhash)){
		av_push(reg, (SV*)SvREFCNT_inc_simple_NN(fieldhash));
	}

	return 0;
}

static int
fieldhash_key_free(pTHX_ SV* const sv, MAGIC* const mg){
	PERL_UNUSED_ARG(sv);

	//warn("key_free(sv=0x%p, mg=0x%p, id=%"SVf")", sv, mg, (SV*)mg->mg_ptr);

	/*
		Does nothing during global destruction, because
		some data may have been released.
	*/
	if(!PL_dirty){
		dMY_CXT;
		AV* const reg    = (AV*)mg->mg_obj; /* field registry */
		SV* const obj_id = (SV*)mg->mg_ptr;
		I32 const len    = AvFILLp(reg)+1;
		I32 i;

		assert(SvTYPE(reg) == SVt_PVAV);
		assert(SvIOK(obj_id));

		av_delete(ObjectRegistry, (I32)SvIVX(obj_id), G_DISCARD);
		hf_free_id(aTHX_ aMY_CXT_ obj_id);

		/* delete $fieldhash{$obj} for each fieldhash */
		for(i = 0; i < len; i++){
			HV* const fieldhash = (HV*)AvARRAY(reg)[i];
			assert(SvTYPE(fieldhash) == SVt_PVHV);

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
	LastId         = -1;
}

#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
	MY_CXT_CLONE;

	ObjectRegistry = get_av(OBJECT_REGISTRY_KEY, GV_ADDMULTI);
	FreeId         = NULL;
	PERL_UNUSED_VAR(items);

#endif /* !USE_ITHREADS */

#if PERL_BCDVERSION >= 0x5010000

void
fieldhash(HV* hash)
PROTOTYPE: \%
CODE:
	assert(SvTYPE(hash) >= SVt_PVMG);
	if(!fieldhash_mg((SV*)hash)){
		hv_clear(hash);
		sv_magic((SV*)hash,
			NULL,                     /* mg_obj */
			PERL_MAGIC_uvar,          /* mg_type */
			(char*)&fieldhash_ufuncs, /* mg_ptr as the ufuncs table */
			0                         /* mg_len (0 indicates static data) */
		);
	}

#else /* < 5.10.0 */

INCLUDE: compat58.xsi

#endif


#ifdef FIELDHASH_DEBUG

void
_dump_internals()
PREINIT:
	dMY_CXT;
	SV* obj_id;
PPCODE:
	for(obj_id = FreeId; obj_id; obj_id = NV2SVPTR(SvNVX(obj_id))){
		sv_dump(obj_id);
	}

#endif /* !FIELDHASH_DEBUG */
