#ifndef _UNISTD_H
#define _UNISTD_H

#include "private/getopt.h"

#define X_OK 1
#define R_OK 4
int access(const char *path, int amode);
int close(int filedes);

#define _PC_LINK_MAX 0

long fpathconf(int fileds, int name);
long pathconf(const char *path, int name);

int link(const char *path1, const char *path2);
unsigned sleep(unsigned seconds);

#endif /* _UNISTD_H */
