// Some of ziglibc is currently in C to have vararg support

#include <stdarg.h>
#include <stdio.h>

// TODO: restrict pointers?
size_t _fwrite_buf(const char *ptr, size_t size, FILE *stream);

// TODO: restrict pointers?
int vfprintf(FILE *stream, const char *format, va_list arg)
{
  size_t len = 0;
  for (; format[len]; len++) { }
  return _fwrite_buf(format, len, stream);
}

// TODO: restrict pointers?
int fprintf(FILE *stream, const char *format, ...)
{
  va_list args;
  va_start(args, format);
  int result = vfprintf(stream, format, args);
  va_end(args);
  return result;
}

int printf(const char *format, ...)
{
  va_list args;
  va_start(args, format);
  int result = vfprintf(stdout, format, args);
  va_end(args);
  return result;
}

int snprintf(char * restrict s, size_t n, const char * restrict format, ...)
{
  fprintf(stderr, "snprintf not implemented");
  abort();
}
