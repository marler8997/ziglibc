#ifndef _SYS_UIO_H
#define _SYS_UIO_H

#include "../../private/size_t.h"
#include "../../private/ssize_t.h"

struct iovec {
  void *iov_base;
  size_t iov_len;
};

ssize_t readv(int, const struct iovec *, int);
ssize_t writev(int, const struct iovec *, int);

#endif /* _SYS_UIO_H */
