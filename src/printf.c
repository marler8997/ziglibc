// Some of ziglibc is currently in C to have vararg support
#include <stdint.h>
#include <assert.h>
#include <errno.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>

// TODO: restrict pointers?
size_t _fwrite_buf(const char *ptr, size_t size, FILE *stream);
size_t _formatCInt(char *buf, int value, uint8_t base);
size_t _formatCUint(char *buf, unsigned value, uint8_t base);
size_t _formatCLong(char *buf, long value, uint8_t base);
size_t _formatCUlong(char *buf, unsigned long value, uint8_t base);
size_t _formatCLonglong(char *buf, long long value, uint8_t base);
size_t _formatCUlonglong(char *buf, unsigned long long value, uint8_t base);

static size_t stringPrintLen(const char *s, unsigned precision) {
  size_t len = 0;
  for (; s[len] && len < (size_t)precision; len++) { }
  return len;
}

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

    // TODO: parse flags
    if (fmt[0] == '-' || fmt[0] == '+' || fmt[0] == ' ' || fmt[0] == '#' || fmt[0] == '0') {
      fprintf(stderr, "error: vformat flag '%c' is not implemented\n", fmt[0]);
      return -1;
    }

    // TODO: parse width
    if (fmt[0] == '*') {
        //width = va_arg(args, int);
        //fmt++;
        fprintf(stderr, "error: vformat number width '*' not implemented\n");
        return -1;
    } else if (fmt[0] >= '0' && fmt[0] <= '9') {
        fprintf(stderr, "error: vformat number width not implemented\n");
        return -1;
    }

    static const int PRECISION_NONE = -1;
    int precision = PRECISION_NONE;
    if (fmt[0] == '.') {
      fmt++;
      if (fmt[0] == '*') {
        precision = va_arg(args, int);
        fmt++;
      } else if (fmt[0] >= '0' && fmt[0] <= '9') {
        fprintf(stderr, "error: vformat precision number '%c' not implemented\n", fmt[0]);
        return -1;
      } else {
        // TODO: don't actually print an error message like this
        // TODO: set errno
        fprintf(stderr, "error: invalid precision specifier : .%s\n", fmt);
        return -1;
      }
    }

    static const unsigned char SPEC_LENGTH_NONE = 0;
    static const unsigned char SPEC_LENGTH_LONG = 1;
    static const unsigned char SPEC_LENGTH_LONG_LONG = 2;
    unsigned char spec_length = SPEC_LENGTH_NONE;
    if (fmt[0] == 'l') {
      if (fmt[1] == 'l') {
        spec_length = SPEC_LENGTH_LONG_LONG;
        fmt += 2;
      } else {
        spec_length = SPEC_LENGTH_LONG;
        fmt++;
      }
    }

    if (fmt[0] == 's') {
      if (spec_length != SPEC_LENGTH_NONE) {
        fprintf(stderr, "error: non-default length not implemented for 's' specifier\n");
        return -1;
      }
      const char *s = va_arg(args, const char *);
      // TODO: is this how we should be handling NULL string pointers?
      if (s == NULL) s = "(null)";

      size_t written = writer->write(writer, s, (precision == PRECISION_NONE) ? 0 : stringPrintLen(s, precision));
      *out_written += written;
      // sanity check
      if ( (precision == PRECISION_NONE) && (s[written] != 0) ) return -1; // error
      fmt++;
    } else if (fmt[0] == 'c') {
      if (spec_length != SPEC_LENGTH_NONE) {
        fprintf(stderr, "error: non-default length not implemented for 'c' specifier\n");
        return -1;
      }
      if (precision != PRECISION_NONE) {
         fprintf(stderr, "error: precision not implemented for 'c' specifier\n");
         return -1;
      }
      char c = va_arg(args, int);
      size_t written = writer->write(writer, &c, 1);
      if (written != 1) return -1;
      *out_written += 1;
      fmt++;
    } else if (fmt[0] == 'd') {
      if (precision != PRECISION_NONE) {
         fprintf(stderr, "error: precision not implemented for 'd' specifier\n");
         return -1;
      }
      char buf[100];
      size_t format_len;
      if (spec_length == SPEC_LENGTH_NONE) {
          const int value = va_arg(args, int);
          format_len = _formatCInt(buf, value, 10);
      } else if (spec_length == SPEC_LENGTH_LONG) {
          const long int value = va_arg(args, long int);
          format_len = _formatCLong(buf, value, 10);
      } else if (spec_length == SPEC_LENGTH_LONG_LONG) {
          const long int value = va_arg(args, long long int);
          format_len = _formatCLonglong(buf, value, 10);
      } else abort();
      size_t written = writer->write(writer, buf, format_len);
      *out_written += written;
      if (written != format_len) return -1; // error
      fmt++;
    } else if (fmt[0] == 'u' || fmt[0] == 'x') {
      uint8_t base = (fmt[0] == 'd') ? 10 : 16;
      if (precision != PRECISION_NONE) {
         fprintf(stderr, "error: precision not implemented for '%c' specifier\n", fmt[0]);
         return -1;
      }
      char buf[100];
      size_t format_len;
      if (spec_length == SPEC_LENGTH_NONE) {
          const unsigned value = va_arg(args, unsigned);
          format_len = _formatCUint(buf, value, base);
      } else if (spec_length == SPEC_LENGTH_LONG) {
          const long unsigned value = va_arg(args, long unsigned);
          format_len = _formatCUlong(buf, value, base);
      } else if (spec_length == SPEC_LENGTH_LONG_LONG) {
          const long unsigned value = va_arg(args, long long unsigned);
          format_len = _formatCUlonglong(buf, value, base);
      } else abort();

      size_t written = writer->write(writer, buf, format_len);
      *out_written += written;
      if (written != format_len) return -1; // error
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
int vfprintf(FILE *stream, const char *format, va_list arg)
{
  struct StreamWriter writer;
  writer.base.write = streamWrite;
  writer.stream = stream;
  size_t written;
  if (0 == vformat(&written, &writer.base, format, arg)) {
    return (int)written;
  }
  stream->errno = errno;
  return -1;
}

int vprintf(const char *format, va_list arg)
{
  return vfprintf(stdout, format, arg);
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

struct BoundedBufferWriter {
  struct Writer base;
  char *buf;
  size_t len;
  char overflow;
};
static size_t boundedBufferWrite(struct Writer *base, const char *s, size_t len)
{
  struct BoundedBufferWriter *writer = (struct BoundedBufferWriter*)base;
  if (len == 0) len = strlen(s);

  if (!writer->overflow) {
    if (len > writer->len) {
      // no need to copy more data
      writer->overflow = 1;
    } else {
      memcpy(writer->buf, s, len);
      writer->buf += len;
      writer->len -= len;
    }
  }
  return len;
}

int vsnprintf(char * restrict s, size_t n, const char * restrict format, va_list args)
{
  struct BoundedBufferWriter writer;
  writer.base.write = boundedBufferWrite;
  writer.buf = s;
  writer.len = n;
  writer.overflow = 0;
  size_t written;
  int result = vformat(&written, &writer.base, format, args);
  assert(result == 0); // vformat can't fail with BoundedBufferWriter
  if (written < n) {
    s[written] = 0;
  }
  return (int)written;
}

int snprintf(char * restrict s, size_t n, const char * restrict format, ...)
{
  va_list args;
  va_start(args, format);
  int result = vsnprintf(s, n, format, args);
  va_end(args);
  return result;
}

struct UnboundedBufferWriter {
  struct Writer base;
  char *buf;
};
static size_t unboundedBufferWrite(struct Writer *base, const char *s, size_t len)
{
  struct UnboundedBufferWriter *writer = (struct UnboundedBufferWriter*)base;
  // TODO: probably should use strncpy if len is 0, could be faster
  if (len == 0) len = strlen(s);
  memcpy(writer->buf, s, len);
  writer->buf += len;
  return len;
}

int vsprintf(char * restrict s, const char * restrict format, va_list args)
{
  struct UnboundedBufferWriter writer;
  writer.base.write = unboundedBufferWrite;
  writer.buf = s;
  size_t written;
  int result = vformat(&written, &writer.base, format, args);
  assert(result == 0); // vformat can't fail with BufferWriter
  s[written] = 0;
  return (int)written;
}

int sprintf(char *s, const char * restrict format, ...)
{
  va_list args;
  va_start(args, format);
  int result = vsprintf(s, format, args);
  va_end(args);
  return result;
}
