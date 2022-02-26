#ifndef _SIGNAL_H
#define _SIGNAL_H

#define SIG_DFL ((void (*)(int)) 0)
#define SIG_IGN ((void (*)(int)) 1)

#define SIGINT 2

typedef int sig_atomic_t;

void (*signal(int sig, void (*func)(int)))(int);

#endif /* _SIGNAL_H */
