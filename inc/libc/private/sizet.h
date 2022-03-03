#ifndef _PRIVATE_SIZET_H
#define _PRIVATE_SIZET_H

// TODO: fixme
#ifdef _WIN32
    typedef unsigned long long size_t;
#else
    typedef unsigned long size_t;
#endif

#endif /* _PRIVATE_SIZET_H */
