#ifndef _STDINT_H
#define _STDINT_H

#if __STDC_VERSION__ < 199901L
    #error stdint.h requires at least c99 I think
#endif

#include "private/int8_t.h"
#include "private/uint8_t.h"
#include "private/int16_t.h"
#include "private/uint16_t.h"
#include "private/int32_t.h"
#include "private/uint32_t.h"
#include "private/int64_t.h"
#include "private/uint64_t.h"

typedef int8_t int_least8_t;
typedef int16_t int_least16_t;
typedef int32_t int_least32_t;
typedef int64_t int_least64_t;
typedef uint8_t uint_least8_t;
typedef uint16_t uint_least16_t;
typedef uint32_t uint_least32_t;
typedef uint64_t uint_least64_t;

typedef int8_t int_fast8_t;
typedef int16_t int_fast16_t;
typedef int32_t int_fast32_t;
typedef int64_t int_fast64_t;
typedef uint8_t uint_fast8_t;
typedef uint16_t uint_fast16_t;
typedef uint32_t uint_fast32_t;
typedef uint64_t uint_fast64_t;

#define INT8_MIN (-128)
#define INT8_MAX (0x7f)
#define INT16_MIN (-32768)
#define INT16_MAX (0x7fff)
#define INT32_MIN (-2147483648)
#define INT32_MAX (0x7fffffff)
#define INT64_MIN (-9223372036854775807LL-1)
#define INT64_MAX (0x7fffffffffffffffLL)

#define UINT8_MAX (0xff)
#define UINT16_MAX (0xffff)
#define UINT32_MAX (0xffffffff)
#define UINT64_MAX (0xffffffffffffffff)

#define INT_LEAST8_MIN INT8_MIN
#define INT_LEAST16_MIN INT16_MIN
#define INT_LEAST32_MIN INT32_MIN
#define INT_LEAST64_MIN INT64_MIN
#define INT_LEAST8_MAX INT8_MAX
#define INT_LEAST16_MAX INT16_MAX
#define INT_LEAST32_MAX INT32_MAX
#define INT_LEAST64_MAX INT64_MAX

#define UINT_LEAST8_MIN UINT8_MIN
#define UINT_LEAST16_MIN UINT16_MIN
#define UINT_LEAST32_MIN UINT32_MIN
#define UINT_LEAST64_MIN UINT64_MIN
#define UINT_LEAST8_MAX UINT8_MAX
#define UINT_LEAST16_MAX UINT16_MAX
#define UINT_LEAST32_MAX UINT32_MAX
#define UINT_LEAST64_MAX UINT64_MAX

#define INT_FAST8_MIN INT8_MIN
#define INT_FAST16_MIN INT16_MIN
#define INT_FAST32_MIN INT32_MIN
#define INT_FAST64_MIN INT64_MIN
#define INT_FAST8_MAX INT8_MAX
#define INT_FAST16_MAX INT16_MAX
#define INT_FAST32_MAX INT32_MAX
#define INT_FAST64_MAX INT64_MAX

#define UINT_FAST8_MIN UINT8_MIN
#define UINT_FAST16_MIN UINT16_MIN
#define UINT_FAST32_MIN UINT32_MIN
#define UINT_FAST64_MIN UINT64_MIN
#define UINT_FAST8_MAX UINT8_MAX
#define UINT_FAST16_MAX UINT16_MAX
#define UINT_FAST32_MAX UINT32_MAX
#define UINT_FAST64_MAX UINT64_MAX

typedef long long intmax_t;
typedef unsigned long long uintmax_t;
typedef struct { intmax_t quot, rem; } imaxdiv_t;

#if __STDC_VERSION__ >= 201112L
    // apparently this type is "optional" in c99 according to https://en.cppreference.com/w/c/types/integer
    typedef long int intptr_t; // TODO: fix this
#endif

#endif /* _STDINT_H */
