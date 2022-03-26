#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <sys/types.h>

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
    printf(#T " %d != %d\n", sizeof(T), b);     \
  }

  check(size_t, ptr_width);
  check(ssize_t, ptr_width);
  check(uint64_t, 8);
  printf("Success!\n");
  return result;
}
