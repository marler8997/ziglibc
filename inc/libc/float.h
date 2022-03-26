#ifndef _FLOAT_H
#define _FLOAT_H

#include "private/limits_and_float_shared.h"

// TODO: I pulled these values from the C Standard, I need to look into them to see what
//       the values should actually be
#define DBL_DIG           10
#define DBL_EPSILON       1E-9
#define DBL_MANT_DIG      53
#define DBL_MAX           1E+37
#define DBL_MAX_10_EXP    37
#define DBL_MAX_EXP       TODO_DEFINE_DBL_MAX_EXP
#define DBL_MIN           1E-37
#define DBL_MIN_10_EXP    -37
#define DBL_MIN_EXP       TODO_DEFINE_DBL_MIN_EXP
#define FLT_DIG           6
#define FLT_EPSILON       1E-5
#define FLT_MANT_DIG      TODO_DEFINE_FLT_MANT_DIG
#define FLT_MAX           1E+37
#define FLT_MAX_10_EXP    37
#define FLT_MAX_EXP       TODO_DEFINE_FLT_MAX_EXP
#define FLT_MIN           1E-37
#define FLT_MIN_10_EXP    -37
#define FLT_MIN_EXP       TODO_DEFINE_FLT_MIN_EXP
#define FLT_RADIX         2
#define FLT_ROUNDS        TODO_DEFINE_FLT_ROUNDS
#define LDBL_DIG          10
#define LDBL_EPSILON      1E-9
#define LDBL_MANT_DIG     TODO_DEFINE_LDBL_MANT_DIG
#define LDBL_MAX          1E+37
#define LDBL_MAX_10_EXP   37
#define LDBL_MAX_EXP      TODO_DEFINE_LDBL_MAX_EXP
#define LDBL_MIN          1E-37
#define LDBL_MIN_10_EXP   -37
#define LDBL_MIN_EXP      TODO_DEFINE_LDBL_MIN_EXP

#if __STDC_VERSION__ >= 199901L
    #define FLT_EVAL_METHOD TODO_DEFINE_FLT_EVAL_METHOD
#endif

#endif /* _FLOAT_H */
