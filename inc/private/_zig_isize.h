#ifndef _PRIVATE_ZIGISIZE_H
#define _PRIVATE_ZIGISIZE_H

// TODO: fixme
#ifdef _WIN32
    typedef long long _zig_isize;
#else

    // TODO: come up with a better way to do this
    #ifdef __x86_64__
        typedef long _zig_isize;
    #else
        typedef int _zig_isize;
    #endif

#endif

#endif /* _PRIVATE_ZIGISIZE_H */
