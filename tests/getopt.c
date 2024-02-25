#include <assert.h>
#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
  int aflag = 0;
  char *c_arg = NULL;
  {
    int c;
    while ((c = getopt(argc, argv, "abc:")) != -1) {
      switch (c) {
      case 'a':
        aflag = 1;
        break;
      case 'c':
        c_arg = optarg;
        break;
      case '?':
        fprintf(stderr, "Unrecognized option: '-%c'\n", optopt);
        return 1;
      default:
        assert(0);
      }
    }
  }
  printf("aflag=%d, c_arg='%s'\n", aflag, c_arg);
  return 0;
}
