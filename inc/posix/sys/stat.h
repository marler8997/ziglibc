#ifndef _SYS_STAT_H
#define _SYS_STAT_H

#include "../../libc/private/restrict.h"
#include "../../libc/private/time_t.h"

#include "../private/dev_t.h"
#include "../private/ino_t.h"
#include "../private/mode_t.h"
#include "../private/nlink_t.h"
#include "../private/uid_t.h"
#include "../private/gid_t.h"
#include "../private/off_t.h"
#include "../private/blksize_t.h"
#include "../private/blkcnt_t.h"

#define S_IXUSR 0100
#define S_IWUSR 0200
#define S_IRUSR 0400
#define S_IRWXG 0070
#define S_IRWXO 0007

struct stat {
  dev_t st_dev;
  ino_t st_ino;
  mode_t st_mode;
  nlink_t st_nlink;
  uid_t st_uid;
  gid_t st_gid;
  dev_t st_rdev;
  off_t st_size;
  time_t st_atime;
  time_t st_mtime;
  time_t st_ctime;
  blksize_t st_blksize;
  blkcnt_t st_blocks;
};

int stat(const char *__zrestrict path, struct stat *__zrestrict buf);
int chmod(const char *path, mode_t mode);
int fstat(int fildes, struct stat *buf);
mode_t umask(mode_t);

#endif /* _SYS_STAT_H */
