#ifndef _TIME_H
#define _TIME_H

#include "../private/null.h"
#include "../private/size_t.h"
#include "../private/time_t.h"
#include "../private/timespec.h"

// CLK_TCK
typedef long clock_t;
struct tm {
    int tm_sec;   /*  seconds after the minute --- [0, 60] */
    int tm_min;   /*  minutes after the hour --- [0, 59] */
    int tm_hour;  /*  hours since midnight --- [0, 23] */
    int tm_mday;  /*  day of the month --- [1, 31] */
    int tm_mon;   /*  months since January --- [0, 11] */
    int tm_year;  /*  years since 1900 */
    int tm_wday;  /*  days since Sunday --- [0, 6] */
    int tm_yday;  /*  days since January 1 --- [0, 365] */
    int tm_isdst; /*  Daylight Saving Time flag */
};

clock_t clock(void);
double difftime(time_t time1, time_t time0);
time_t mktime(struct tm *timeptr);
time_t time(time_t *timer);
char *asctime(const struct tm *timeptr);
char *ctime(const time_t *timer);
struct tm *gmtime(const time_t *timer);
struct tm *localtime(const time_t *timer);
size_t strftime(char *s, size_t maxsize,
const char *format, const struct tm *timeptr);

#if __STDC_VERSION__ >= 199901L
    #define CLOCKS_PER_SEC 1000000L
#endif

#if __STDC_VERSION__ >= 201112L
    #define TIME_UTC 1
#endif
// NOTE: it looks like the definitions in this block are defined by posix (not libc)
//       but they need to be in time.h defined by libc (not posix)
//       so for now I'm just including it here
#if 1
    typedef int clockid_t;
    #define CLOCK_REALTIME 0
    #if __STDC_VERSION__ >= 201112L
        int clock_gettime(clockid_t clk_id, struct timespec *tp);
    #endif
#endif

#endif /* _TIME_H */
