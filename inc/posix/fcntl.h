#ifndef _FCNTL_H
#define _FCNTL_H

#define O_RDONLY          0
#define O_WRONLY         01
#define O_RDWR           02
#define O_APPEND        010
#define O_CREAT        0100
#define O_TRUNC       01000
#define O_CLOEXEC  02000000
#define O_EXEC    010000000

int open(const char *path, int oflag, ...);
int openat(int fd, const char *path, int oflag, ...);

#endif /* _FCNTL_H */
