#ifndef _SYS_SELECT_H
#define _SYS_SELECT_H

// According to POSIX.1-2001
#if 1
    #include "../../private/timespec.h"
    #include "../../private/fd_set.h"
    #include "../../private/sigset_t.h"
    #include "../../private/timeval.h"

    void FD_CLR(int fd, fd_set *fdset);
    int FD_ISSET(int fd, fd_set *fdset);
    void FD_SET(int fd, fd_set *fdset);
    void FD_ZERO(fd_set *fdset);

    int pselect(int, fd_set *restrict, fd_set *restrict, fd_set *restrict,
        const struct timespec *restrict, const sigset_t *restrict);
    int select(int, fd_set *restrict, fd_set *restrict, fd_set *restrict,
        struct timeval *restrict);
#endif

#endif /* _SYS_SELECT_H */
