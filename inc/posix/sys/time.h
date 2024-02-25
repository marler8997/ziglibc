#ifndef _SYS_TIME_H
#define _SYS_TIME_H

#include "../../private/suseconds_t.h"
#include "../../private/fd_set.h"

#include "../../private/time_t.h"
#include "../../private/timeval.h"

#define ITIMER_REAL 0
#define ITIMER_VIRTUAL 1
#define ITIMER_PROF 2

struct itimerval {
  struct timeval it_interval;
  struct timeval it_value;
};

int getitimer(int, struct itimerval *);
int setitimer(int, const struct itimerval *, struct itimerval *);
int gettimeofday(struct timeval *, void *);
int select(int, fd_set *, fd_set *, fd_set *, struct timeval *);
int utimes(const char *, const struct timeval [2]);

#endif /* _SYS_TIME_H */

