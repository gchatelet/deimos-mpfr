module deimos.gmp;

import core.stdc.config : c_long, c_ulong;

nothrow extern(C):

alias mp_limb_t = c_ulong;

struct __mpz_struct {
  int _mp_alloc;
  int _mp_size;
  mp_limb_t *_mp_d;
}

alias mpz_t = __mpz_struct;

struct __mpq_struct {
  __mpz_struct _mp_num;
  __mpz_struct _mp_den;
}

alias mpq_t = __mpq_struct;

alias mp_exp_t = c_long;

struct __mpf_struct {
  int _mp_prec;
  int _mp_size;
  mp_exp_t _mp_exp;
  mp_limb_t *_mp_d;
}

alias mpf_t = __mpf_struct;

