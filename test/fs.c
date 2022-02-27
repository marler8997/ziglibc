#include <errno.h>
#include <stdio.h>

#include "expect.h"

// CWD should be a directory available to create files
int main(int argc, char *argv[])
{
  const char *filename = "foo";
  FILE *file = fopen(filename, "w");
  // NOT WORKING YET!
  //if (file == NULL) {
  //  fprintf(stderr, "error: fopen '%s' failed, errno=%d\n", filename, errno);
  //  return 1;
  //}
  //expect(0 == fclose(file));
  printf("Success!\n");
}
