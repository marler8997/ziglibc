#ifndef _UNISTD_H
#define _UNISTD_H

#include "private/getopt.h"

#define X_OK 1
#define R_OK 4
int access(const char *path, int amode);


#endif /* _UNISTD_H */
