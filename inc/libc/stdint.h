#ifndef _STDINT_H
#define _STDINT_H

#if __STDC_VERSION__ < 199901L
    #error stdint.h requires at least c99 I think
#endif

#include "private/uint16_t.h"
#include "private/uint32_t.h"
#include "private/uint64_t.h"

#if __STDC_VERSION__ >= 201112L
    // apparently this type is "optional" in c99 according to https://en.cppreference.com/w/c/types/integer
    typedef long int intptr_t; // TODO: fix this
#endif

#endif /* _STDINT_H */
