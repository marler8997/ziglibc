#ifndef _SIGNAL_H
#define _SIGNAL_H

#define SIG_DFL ((void (*)(int)) 0)
#define SIG_IGN ((void (*)(int)) 1)

#define SIGINT 2

typedef int sig_atomic_t;

void (*signal(int sig, void (*func)(int)))(int);


/* TODO: these are posix definitions for the signal.h libc header */
#if 1
    #include "private/restrict.h"
    #include "../posix/private/sigset_t.h"
    #include "../posix/private/pid_t.h"
    #include "../posix/private/uid_t.h"

    #define SIGALRM 14
    union sigval {
      int sival_int;
      void *sival_ptr;
    };
    typedef struct {
      int si_signo;
      int si_code;
      int si_errno;
      pid_t si_pid;
      uid_t si_uid;
      void *si_addr;
      int si_status;
      long si_band;
      union sigval si_value;
    } siginfo_t;
    struct sigaction {
      void (*sa_handler)(int);
      sigset_t sa_mask;
      int sa_flags;
      void (*sa_sigaction)(int, siginfo_t *,void*);
    };
    int sigaction(
        int sig,
        const struct sigaction *__zrestrict act,
        struct sigaction *__zrestrict oact);
#endif


#endif /* _SIGNAL_H */
