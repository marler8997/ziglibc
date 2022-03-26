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

#define check_equal(prefix, fmt_spec, expected, actual)                 \
  if (expected != actual) {                                             \
    result = -1;                                                        \
    printf(prefix " expected " fmt_spec " but got " fmt_spec "\n", expected, actual); \
  }

#define check_sizeof(T,b)                               \
  if (sizeof(T) != b) {                                 \
    result = -1;                                        \
    printf(#T " %u != %u\n", (unsigned)sizeof(T), b);   \
  }

  check_sizeof(size_t, ptr_width);
  check_sizeof(ssize_t, ptr_width);
  check_sizeof(uint64_t, 8);

  if (INT_MAX == 2147483647) {
    check_equal("UINT_MAX", "%u", 0xffffffff, UINT_MAX);
    check_sizeof(int, 4);
    check_sizeof(unsigned, 4);
  } else {
    result = -1;
    fprintf(stderr, "unhandled INT_MAX value %d", INT_MAX);
  }

  if (LONG_MAX == 2147483647L) {
    check_equal("ULONG_MAX", "%lu", 0xffffffff, ULONG_MAX);
    check_sizeof(long, 4);
    check_sizeof(unsigned long, 4);
  } else if (LONG_MAX == 9223372036854775807L) {
    check_equal("ULONG_MAX", "%lu", 0xffffffffffffffff, ULONG_MAX);
    check_sizeof(long, 8);
    check_sizeof(unsigned long, 8);
  } else {
    result = -1;
    fprintf(stderr, "unhandled LONG_MAX value %d", LONG_MAX);
  }

  if (LLONG_MAX == 9223372036854775807) {
    check_equal("ULLONG_MAX", "%lu", 0xffffffffffffffff, ULLONG_MAX);
    check_sizeof(long long, 8);
    check_sizeof(unsigned long long, 8);
  } else {
    result = -1;
    fprintf(stderr, "unhandled LLONG_MAX value %lld", LONG_MAX);
  }

  printf("Success!\n");
  return result;
}
