#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <sys/types.h>
#include <limits.h>

int main(int argc, char *argv[])
{
  argc--; argv++;
  if (argc != 1) {
    fprintf(stderr, "expected 1 cmd-line arg but got %d\n", argc);
    return -1;
  }
  char *ptr_width_str = argv[0];
  unsigned ptr_width;
  if (0 == strcmp(ptr_width_str, "4")) {
    ptr_width = 4;
  } else if (0 == strcmp(ptr_width_str, "8")) {
    ptr_width = 8;
  } else {
    fprintf(stderr, "unknown ptr width '%s'\n", ptr_width_str);
    return -1;
  }

  int result = 0;

#define check(T,b)                              \
  if (sizeof(T) != b) {                         \
    result = -1;                                \
    printf(#T " %u != %u\n", (unsigned)sizeof(T), b);   \
  }

  check(size_t, ptr_width);
  check(ssize_t, ptr_width);
  check(uint64_t, 8);

  if (INT_MAX == 2147483647) {
    check(int, 4);
  } else {
    result = -1;
    fprintf(stderr, "unhandled INT_MAX value %d", INT_MAX);
  }
  if (UINT_MAX == 0xffffffffU) {
    check(unsigned, 4);
  } else {
    result = -1;
    fprintf(stderr, "unhandled UINT_MAX value %u", UINT_MAX);
  }
  if (LONG_MAX == 2147483647L) {
    check(long, 4);
  } else if (LONG_MAX == 9223372036854775807L) {
    check(long, 8);
  } else {
    result = -1;
    fprintf(stderr, "unhandled LONG_MAX value %d", LONG_MAX);
  }

  printf("Success!\n");
  return result;
}
