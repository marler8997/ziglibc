#ifndef _FD_SET_H
#define _FD_SET_H

#define FD_SETSIZE 1024
// TODO: fixme
typedef struct {
  unsigned fds_bits[FD_SETSIZE / (sizeof(unsigned) * 8)];
} fd_set;

#endif /* _FD_SET_H */
