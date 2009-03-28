/* compat58.h */

#ifndef HV_FETCH
#define HV_FETCH          0x00
#endif

#ifndef HV_FETCH_ISSTORE
#define HV_FETCH_ISSTORE  0x04
#define HV_FETCH_ISEXISTS 0x08
#define HV_FETCH_LVALUE   0x10
#define HV_FETCH_JUST_SV  0x20
#define HV_DELETE         0x40
#endif

#ifndef newSV_type
#define newSV_type(t) my_newSV_type(aTHX_ t)
static SV*
my_newSV_type(pTHX_ svtype const t){
	SV* const sv = newSV(0);
	sv_upgrade(sv, t);
	return sv;
}
#endif

#ifndef gv_fetchpvs
#define gv_fetchpvs(name, flags, svt) gv_fetchpv((name ""), flags, svt)
#endif

#ifndef gv_stashpvs
#define gv_stashpvs(name, flags) Perl_gv_stashpvn(aTHX_ STR_WITH_LEN(name), flags)
#endif

#ifndef HvNAME_get
#define HvNAME_get(stash) HvNAME(stash)
#endif

#ifndef HvNAMELEN_get
#define HvNAMELEN_get(stash) my_HvNAME_get(aTHX_ stash)
static I32
my_HvNAME_get(pTHX_ HV* const stash){
	const char* const name = HvNAME_get(stash);
	assert(name);
	return strlen(name);
}
#endif

static MGVTBL fieldhash_vtbl;
#define fieldhash_mg(sv) mg_find_by_vtbl(sv, &fieldhash_vtbl)

static I32 fieldhash_watch(pTHX_ IV const action, SV* const fieldhash);

static SV*
hf_replace_key(pTHX_ HV* const impl, SV* key, IV const action){
	MAGIC* const mg = fieldhash_mg((SV*)impl);

	if(!mg){
		Perl_croak(aTHX_ "panic: invalid fieldhash");
	}

	mg->mg_obj = key;
	fieldhash_watch(aTHX_ action, (SV*)impl);
	key = mg->mg_obj;
	mg->mg_obj = NULL;

	return key;
}

static HV*
fieldhash_get_impl(pTHX_ HV* const fieldhash){
	MAGIC* const tied_mg  = SvTIED_mg((SV*)fieldhash, PERL_MAGIC_tied);
	SV*    const tied_obj = SvTIED_obj((SV*)fieldhash, tied_mg);

	assert(sv_derived_from(tied_obj, PACKAGE));
	assert(SvROK(tied_obj));
	assert(SvTYPE(SvRV(tied_obj)) == SVt_PVHV);

	return (HV*)SvRV(tied_obj);
}

static SV*
fieldhash_fetch(pTHX_ HV* const fieldhash, SV* const key){
	HV* const impl = fieldhash_get_impl(aTHX_ fieldhash);
	HE* he;

	he = hv_fetch_ent(impl, hf_replace_key(aTHX_ impl, key, HV_FETCH), FALSE, 0U);
	return he ? HeVAL(he) : &PL_sv_undef;
}

static void
fieldhash_store(pTHX_ HV* const fieldhash, SV* const key, SV* const val){
	HV* const impl = fieldhash_get_impl(aTHX_ fieldhash);

	(void)hv_store_ent(impl, hf_replace_key(aTHX_ impl, key, HV_FETCH_ISSTORE), val, 0U);
}

