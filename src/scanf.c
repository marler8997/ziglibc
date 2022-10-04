// Some of ziglibc is currently in C to have vararg support
#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>

struct Reader {
  size_t (*read)(struct Reader *reader, const char **out_buf);
};

// returns: the number of arguments scanned, EOF on error
static int vscanf(struct Reader *reader, const char *fmt, va_list args) {
    fprintf(stderr, "vscanf not implemented");
    return -1;
}

struct FixedReader {
  struct Reader base;
  const char *buf;
};
size_t fixedReaderRead(struct Reader *base, const char **out_buf) {
  struct FixedReader *reader = (struct FixedReader*)base;
  if (reader->buf) {
      *out_buf = reader->buf;
      reader->buf = NULL;
      return strlen(*out_buf);
  }
  return 0;
}

int sscanf(const char *s, const char *fmt, ...) {
  struct FixedReader reader;
  reader.base.read = fixedReaderRead;
  reader.buf = s;
  va_list args;
  va_start(args, fmt);
  int result = vscanf(&reader.base, fmt, args);
  va_end(args);
  return result;
}
