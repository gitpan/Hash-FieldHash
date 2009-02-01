/* compat58.h */

#ifndef HV_FETCH_ISSTORE
#define HV_FETCH_ISSTORE  0x04
#define HV_FETCH_ISEXISTS 0x08
#define HV_FETCH_LVALUE   0x10
#define HV_FETCH_JUST_SV  0x20
#define HV_DELETE         0x40
#endif

#ifndef gv_fetchpvs
#define gv_fetchpvs(name, flags, svt) gv_fetchpv((name ""), flags, svt)
#endif

#ifndef gv_stashpvs
#define gv_stashpvs(name, flags) Perl_gv_stashpvn(aTHX_ STR_WITH_LEN(name), flags)
#endif

#ifndef PL_unitcheckav
#define PL_unitcheckav NULL
#endif

MGVTBL fieldhash_vtbl;
#define fieldhash_mg(sv) my_mg_find_by_vtbl(aTHX_ sv, &fieldhash_vtbl)

