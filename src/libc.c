// Some of ziglibc is currently in C to have vararg support
#include <errno.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

// TODO: restrict pointers?
size_t _fwrite_buf(const char *ptr, size_t size, FILE *stream);
size_t _formatCInt(char *buf, int value);

struct Writer {
  // if len is 0, then s is null-terminated
  // returns the total number of bytes written
  // if the number of bytes written is less than len (or strlen(s))
  // then errno should be set
  size_t (*write)(struct Writer *writer, const char *s, size_t len);
};
// returns: 0 on success
static int vformat(size_t *out_written, struct Writer *writer, const char *fmt, va_list args) {
  *out_written = 0;

  while (1) {
    const char *next_percent_char = strchr(fmt, '%');
    if (next_percent_char == NULL) break;

    {
      size_t len = next_percent_char - fmt;
      if (len > 0) {
        size_t written = writer->write(writer, fmt, len);
        *out_written += written;
        if (written != len) {
          return -1; // error
        }
      }
    }
    fmt = next_percent_char + 1;
    if (fmt[0] == 's') {
      const char *s = va_arg(args, const char *);
      size_t written = writer->write(writer, s, 0);
      *out_written += written;
      if (s[written] != 0) return -1; // error
      fmt++;
    } else if (fmt[0] == 'd') {
      char buf[100];
      const int value = va_arg(args, int);
      size_t len = _formatCInt(buf, value);
      size_t written = writer->write(writer, buf, len);
      *out_written += written;
      if (written != len) return -1; // error
      fmt++;
    } else if (fmt[0] == 0) {
      return -1; // spurious trailing '%'
    } else {
      fprintf(stderr, "error: vformat specifer not implemented: '%s'\n", fmt-1);
      return -1;
    }
  }
  if (fmt[0] != 0) {
    size_t written = writer->write(writer, fmt, 0);
    *out_written += written;
    if (fmt[written] != 0) {
      return -1; // error
    }
  }

  return 0;
}

struct StreamWriter {
  struct Writer base;
  FILE *stream;
};
static size_t streamWrite(struct Writer *base, const char *s, size_t len)
{
  struct StreamWriter *writer = (struct StreamWriter*)base;
  if (len == 0) len = strlen(s);
  return _fwrite_buf(s, len, writer->stream);
}

// TODO: restrict pointers?
int vfprintf(FILE *stream, const char *format, va_list args)
{
  struct StreamWriter writer;
  writer.base.write = streamWrite;
  writer.stream = stream;
  size_t written;
  if (0 == vformat(&written, &writer.base, format, args)) {
    return (int)written;
  }
  stream->errno = errno;
  return -1;
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

struct BufferWriter {
  struct Writer base;
  char *buf;
  size_t len;
};
static size_t bufferWrite(struct Writer *base, const char *s, size_t len)
{
  struct BufferWriter *writer = (struct BufferWriter*)base;
  if (len == 0) len = strlen(s);
  if (len > writer->len) {
    fprintf(stderr, "bufferWrite overflow, todo: implement fallback that returns write size\n");
    return 0;
  }
  memcpy(writer->buf, s, len);
  writer->buf += len;
  writer->len -= len;
  return len;
}

int vsnprintf(char * restrict s, size_t n, const char * restrict format, va_list args)
{
  struct BufferWriter writer;
  writer.base.write = bufferWrite;
  writer.buf = s;
  writer.len = n;
  size_t written;
  if (0 == vformat(&written, &writer.base, format, args)) {
    // TODO: make sure this comparison isn't off by 1
    if (written < n) {
      s[written] = 0;
    }
    return (int)written;
  }
  return -1;
}

int snprintf(char * restrict s, size_t n, const char * restrict format, ...)
{
  va_list args;
  va_start(args, format);
  int result = vsnprintf(s, n, format, args);
  va_end(args);
  return result;
}
