#ifndef _LIMITS_H
#define _LIMITS_H

#include "../private/limits_and_float_shared.h"

#if __STDC_VERSION__ >= 199901L
    /* assume 64-bit long long for now */
    #define LLONG_MAX  9223372036854775807
    #define LLONG_MIN -9223372036854775807
    #define ULLONG_MAX 18446744073709551615
#endif

/* TODO: fixme */
/* TODO: I think PATH_MAX is supposed to be in "linux/limits.h" rather than "limits.h"?? */
#define PATH_MAX 1024

#endif /* _LIMITS_H */
