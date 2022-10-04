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

// TODO: I'm not sure what standard defines the fixed-width MAX defines
#define INT32_MAX 0x7fffffff
#define UINT32_MAX 0xffffffff

#if __STDC_VERSION__ >= 201112L
    // apparently this type is "optional" in c99 according to https://en.cppreference.com/w/c/types/integer
    typedef long int intptr_t; // TODO: fix this
#endif

#endif /* _STDINT_H */
