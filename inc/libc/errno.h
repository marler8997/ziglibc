#ifndef _ERRNO_H
#define _ERRNO_H

extern int errno;

/* NOTE: these are defined by posix */
#if 1
    /* TODO: these can change based on platform, for now I'm just worrying about x86 */
    #define ENOENT 2
    #define EINTR 4
    #define EAGAIN 11
    #define ENOMEM 12
    #define EACCES 13
    #define EEXIST 17
    #define EINVAL 22
    #define ENOTTY 25
    #define ERANGE 34
    #define EWOULDBLOCK 140
    #define ECONNREFUSED 111
#endif

#endif /* _ERRNO_H */
