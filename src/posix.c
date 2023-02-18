// NOTE: contains the implementations of functions for libposix
//       that require varargs
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

// --------------------------------------------------------------------------------
// fcntl
// --------------------------------------------------------------------------------
int open(const char *path, int oflag, lll)
{
    fprintf(stderr, "open function not implemented\n");
    abort();
}

// --------------------------------------------------------------------------------
// sys/ioctl
// --------------------------------------------------------------------------------
int _ioctlArgPtr(int fd, unsigned long request, void *arg);

int ioctl(int fd, unsigned long request, ...)
{
    va_list args;
    va_start(args, request);
    void *arg_ptr = va_arg(args, void*);
    va_end(args);
    return _ioctlArgPtr(fd, request, arg_ptr);
}
