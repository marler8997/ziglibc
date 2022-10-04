#ifndef _UNISTD_H
#define _UNISTD_H

#include "../libc/private/size_t.h"
#include "private/getopt.h"
#include "private/ssize_t.h"

#define X_OK 1
#define R_OK 4
int access(const char *path, int amode);
int close(int filedes);

ssize_t read(int filedes, void *buf, size_t nbyte);
ssize_t write(int fildes, const void *buf, size_t nbyte);

#define _PC_LINK_MAX 0

long fpathconf(int fileds, int name);
long pathconf(const char *path, int name);

int link(const char *path1, const char *path2);
unsigned sleep(unsigned seconds);

int unlink(const char *path);
void _exit(int status);

int gethostname(char *name, size_t namelen);
int isatty(int filedes);

#endif /* _UNISTD_H */
