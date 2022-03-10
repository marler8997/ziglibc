#ifndef _SIGNAL_H
#define _SIGNAL_H

#define SIG_DFL ((void (*)(int)) 0)
#define SIG_IGN ((void (*)(int)) 1)

#define SIGINT 2

typedef int sig_atomic_t;

void (*signal(int sig, void (*func)(int)))(int);


// TODO: these are posix definitions for the signal.h libc header
#if 1
    #define SIGALRM 14
    typedef struct { unsigned long __signals; } sigset_t;
    union sigval {
      int sival_int;
      void *sival_ptr;
    };
    typedef struct {
      int si_signo;
      int si_code;
      int si_errno;
      //pid_t si_pid;
      int si_pid; // TODO: use pid_t instead
      //uid_t si_uid;
      int si_uid; // TODO: use uid_t instead
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
#endif


#endif /* _SIGNAL_H */
