#ifndef _SYS_IOCTL_H
#define _SYS_IOCTL_H

// TODO: will change depending on platform
#define FIONBIO 0x5421

int ioctl(int fd, unsigned long request, ...);

#endif /*  _SYS_IOCTL_H */
