#ifndef _INTTYPES_H
#define _INTTYPES_H

#if __STDC_VERSION__ < 199901L
    #error inttypes.h requires at least c99 I think
#endif

// most headers don't include other headers, but, this one by definition
// also includes stdint.h and extends it
#include "stdint.h"

#define PRId32 "d"
#define PRIx32 "x"

#endif /* _INTTYPES_H */
