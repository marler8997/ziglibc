// NOTE: contains the implementations of functions for libposix
//       that require varargs
#include <stdlib.h>
#include <stdio.h>

int ioctl(int fd, unsigned long request, ...)
{
  fprintf(stderr, "ioctl fd=%d request=%d not implemented\n", fd, request);
  abort();
}
