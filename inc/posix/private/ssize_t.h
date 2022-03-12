#ifndef _PRIVATE_SSIZET_H
#define _PRIVATE_SSIZET_H

// TODO: fixme
#ifdef _WIN32
    typedef long long ssize_t;
#else

    // TODO: come up with a better way to do this
    #ifdef __x86_64__
        typedef long ssize_t;
    #else
        typedef int ssize_t;
    #endif

#endif

#endif /* _PRIVATE_SSIZET_H */
