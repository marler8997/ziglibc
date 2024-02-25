#ifndef _DIRENT_H
#define _DIRENT_H

#include "../private/ino_t.h"

typedef struct DIR DIR;
struct dirent {
    ino_t d_ino;
    char d_name[];
};

DIR *opendir(const char *dirname);
int closedir(DIR *);
DIR *fdopendir(int fd);

struct dirent *readdir(DIR *);

#endif /* _DIRENT_H */
