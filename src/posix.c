// NOTE: contains the implementations of functions for libposix
//       that require varargs
#include <stdio.h>

int ioctl(int fd, unsigned long request, ...)
{
  fprintf(stderr, "iocto fd=%d request=%d not implemented\n", fd, request);
  abort();
}
