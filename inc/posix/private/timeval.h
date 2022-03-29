#ifndef _PRIVATE_TIMEVAL_H
#define _PRIVATE_TIMEVAL_H

#include "../../libc/private/time_t.h"
#include "suseconds_t.h"

struct timeval {
  time_t tv_sec;
  suseconds_t tv_usec;
};

#endif /* _PRIVATE_TIMEVAL_H */
