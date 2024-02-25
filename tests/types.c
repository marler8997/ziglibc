#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <sys/types.h>
#include <limits.h>
#include <float.h>

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

#define fail(msg, ...) do {                     \
    result = -1;                                \
    fprintf(stderr, msg "\n", ##__VA_ARGS__);    \
  } while(0)

#define check_equal(prefix, fmt_spec, expected, actual)                 \
  if (expected != actual) {                                             \
    result = -1;                                                        \
    fprintf(stderr, prefix " expected " fmt_spec " but got " fmt_spec "\n", expected, actual); \
  }

#define check_sizeof(T,b)                                        \
  if (sizeof(T) != b) {                                          \
    result = -1;                                                 \
    fprintf(stderr, #T " %u != %u\n", (unsigned)sizeof(T), b);   \
  }

  check_sizeof(size_t, ptr_width);
  check_sizeof(ssize_t, ptr_width);
  check_sizeof(ptrdiff_t, ptr_width);
  check_sizeof(int8_t, 1);
  check_sizeof(uint8_t, 1);
  check_sizeof(int16_t, 2);
  check_sizeof(uint16_t, 2);
  check_sizeof(int32_t, 4);
  check_sizeof(uint32_t, 4);
  check_sizeof(int64_t, 8);
  check_sizeof(uint64_t, 8);

#define check_size_atleast(T,b)                                 \
  if (sizeof(T) < b) {                                           \
    result = -1;                                               \
    fprintf(stderr, #T " %u < %u\n", (unsigned)sizeof(T), b); \
  }

  check_size_atleast(int_least8_t, 1);
  check_size_atleast(int_least16_t, 2);
  check_size_atleast(int_least32_t, 4);
  check_size_atleast(int_least64_t, 8);
  check_size_atleast(uint_least8_t, 1);
  check_size_atleast(uint_least16_t, 2);
  check_size_atleast(uint_least32_t, 4);
  check_size_atleast(uint_least64_t, 8);

  check_size_atleast(int_fast8_t, 1);
  check_size_atleast(int_fast16_t, 2);
  check_size_atleast(int_fast32_t, 4);
  check_size_atleast(int_fast64_t, 8);
  check_size_atleast(uint_fast8_t, 1);
  check_size_atleast(uint_fast16_t, 2);
  check_size_atleast(uint_fast32_t, 4);
  check_size_atleast(uint_fast64_t, 8);

  check_equal("SCHAR_MAX", "%d", 127, SCHAR_MAX);
  check_equal("UCHAR_MAX", "%d", 255, UCHAR_MAX);
  if ((int)((char)-1) == -1) {
      check_equal("CHAR_MAX", "%d", SCHAR_MAX, CHAR_MAX);
  } else {
      check_equal("CHAR_MAX", "%d", UCHAR_MAX, CHAR_MAX);
  }

  if (INT_MAX == 2147483647) {
    check_equal("UINT_MAX", "%u", 0xffffffff, UINT_MAX);
    check_sizeof(int, 4);
    check_sizeof(unsigned, 4);
  } else {
    fail("unhandled INT_MAX value %d", INT_MAX);
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
    fail("unhandled LONG_MAX value %d", LONG_MAX);
  }

  if (LLONG_MAX == 9223372036854775807) {
    check_equal("ULLONG_MAX", "%lu", 0xffffffffffffffff, ULLONG_MAX);
    check_sizeof(long long, 8);
    check_sizeof(unsigned long long, 8);
  } else {
    fail("unhandled LLONG_MAX value %lld", LONG_MAX);
  }

  if (DBL_MANT_DIG == 53) {
    check_sizeof(double, 8);
  } else {
    fail("unhandled DBL_MANT_DIG %u", (unsigned)DBL_MANT_DIG);
  }

  check_equal("UINT64_C(0xffff...)", "%llu", 0xffffffffffffffffllu, UINT64_C(0xffffffffffffffff));

  if (result == 0) {
    printf("Success!\n");
  }
  return result;
}
