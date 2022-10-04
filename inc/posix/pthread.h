#ifndef _PTHREAD_H
#define _PTHREAD_H

#define PTHREAD_BARRIER_SERIAL_THREAD TODO_DEFINE_PTHREAD_BARRIER_SERIAL_THREAD 
#define PTHREAD_CANCEL_ASYNCHRONOU TODO_DEFINE_PTHREAD_CANCEL_ASYNCHRONOUS
#define PTHREAD_CANCEL_ENABL TODO_DEFINE_PTHREAD_CANCEL_ENABLE
#define PTHREAD_CANCEL_DEFERRE TODO_DEFINE_PTHREAD_CANCEL_DEFERRED
#define PTHREAD_CANCEL_DISABL TODO_DEFINE_PTHREAD_CANCEL_DISABLE
#define PTHREAD_CANCELE TODO_DEFINE_PTHREAD_CANCELED
#define PTHREAD_CREATE_DETACHE TODO_DEFINE_PTHREAD_CREATE_DETACHED
#define PTHREAD_CREATE_JOINABL TODO_DEFINE_PTHREAD_CREATE_JOINABLE
#define PTHREAD_EXPLICIT_SCHE TODO_DEFINE_PTHREAD_EXPLICIT_SCHED
#define PTHREAD_INHERIT_SCHE TODO_DEFINE_PTHREAD_INHERIT_SCHED
#define PTHREAD_MUTEX_DEFAUL TODO_DEFINE_PTHREAD_MUTEX_DEFAULT
#define PTHREAD_MUTEX_ERRORCHEC TODO_DEFINE_PTHREAD_MUTEX_ERRORCHECK
#define PTHREAD_MUTEX_NORMA TODO_DEFINE_PTHREAD_MUTEX_NORMAL
#define PTHREAD_MUTEX_RECURSIV TODO_DEFINE_PTHREAD_MUTEX_RECURSIVE
#define PTHREAD_MUTEX_ROBUS TODO_DEFINE_PTHREAD_MUTEX_ROBUST
#define PTHREAD_MUTEX_STALLE TODO_DEFINE_PTHREAD_MUTEX_STALLED
#define PTHREAD_ONCE_INI TODO_DEFINE_PTHREAD_ONCE_INIT
#define PTHREAD_PRIO_INHERI TODO_DEFINE_PTHREAD_PRIO_INHERIT
#define PTHREAD_PRIO_NON TODO_DEFINE_PTHREAD_PRIO_NONE
#define PTHREAD_PRIO_PROTEC TODO_DEFINE_PTHREAD_PRIO_PROTECT
#define PTHREAD_PROCESS_SHARE TODO_DEFINE_PTHREAD_PROCESS_SHARED
#define PTHREAD_PROCESS_PRIVAT TODO_DEFINE_PTHREAD_PROCESS_PRIVATE
#define PTHREAD_SCOPE_PROCES TODO_DEFINE_PTHREAD_SCOPE_PROCESS
#define PTHREAD_SCOPE_SYSTE TODO_DEFINE_PTHREAD_SCOPE_SYSTEM

// TODO: define this properly
typedef int pthread_attr_t;
typedef int pthread_barrier_t;
typedef int pthread_barrierattr_t;
typedef int pthread_cond_t;
typedef int pthread_condattr_t;
typedef int pthread_key_t;
typedef int pthread_mutex_t;
typedef int pthread_mutexattr_t;
typedef int pthread_once_t;
typedef int pthread_rwlock_t;
typedef int pthread_rwlockattr_t;
typedef int pthread_spinlock_t;
typedef int pthread_t;

#define PTHREAD_MUTEX_INITIALIZER {0}
int pthread_mutex_init(pthread_mutex_t *restrict, const pthread_mutexattr_t *restrict);
int pthread_mutex_destroy(pthread_mutex_t *);
int pthread_mutex_lock(pthread_mutex_t *);
int pthread_mutex_unlock(pthread_mutex_t *);

#define PTHREAD_COND_INITIALIZER {0}
int pthread_cond_init(pthread_cond_t *cond, const pthread_condattr_t *attr);
int pthread_cond_destroy(pthread_cond_t *cond);
int pthread_cond_wait(pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex);
int pthread_cond_broadcast(pthread_cond_t *cond);
int pthread_cond_signal(pthread_cond_t *cond);

#endif /* _PTHREAD_H */
