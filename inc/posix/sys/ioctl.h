#ifndef _SYS_IOCTL_H
#define _SYS_IOCTL_H

int ioctl(int filedes, int request, ...);

// NOTE: this stuff is defined by linux, not posix, but they need
//       to live in this header
#if 1
    // TODO: will change depending on platform
    #define FIONBIO 0x5421
#endif


#endif /* SYS_IOCTL_H */
