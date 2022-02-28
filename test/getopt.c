#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
  int c;
  while ((c = getopt(argc, argv, ":abf:o:")) != 1) {
    switch (c) {
    case '?':
      fprintf(stderr, "Unrecognized option: '-%c'\n", optopt);
      return 1;
    }
  }
  return 0;
}
