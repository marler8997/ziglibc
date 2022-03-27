#ifndef _FCNTL_H
#define _FCNTL_H

#define O_RDONLY          0
#define O_WRONLY         01
#define O_RDWR           02
#define O_APPEND        010
#define O_CREAT        0100
#define O_EXCL         0200
#define O_TRUNC       01000
#define O_NONBLOCK    04000
#define O_CLOEXEC  02000000
#define O_EXEC    010000000

int open(const char *path, int oflag, ...);
int openat(int fd, const char *path, int oflag, ...);

// --------------------------------------------------------------------------------
// NOTE: fcntl and the F_* constants may also optionally be in unistd.h according to the posix docs
// --------------------------------------------------------------------------------
#define F_DUPFD 0
#define F_GETFD 1
#define F_SETFD 2
#define F_GETFL 3
#define F_SETFL 4
#define F_GETOWN 5
#define F_SETOWN 6
#define FD_CLOEXEC 1
int fcntl(int fildes, int cmd, ...);
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------
// --------------------------------------------------------------------------------

#endif /* _FCNTL_H */
