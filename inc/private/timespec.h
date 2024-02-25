#ifndef _PRIVATE_TIMEPEC_H
#define _PRIVATE_TIMEPEC_H

#if __STDC_VERSION__ >= 201112L
    #include "time_t.h"
    struct timespec {
        time_t tv_sec; // whole seconds >= 0
        long tv_nsec; // nanoseconds [0,999999999]
    };
#endif

#endif /* _PRIVATE_TIMEPEC_H */
