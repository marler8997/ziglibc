#include <stdio.h>

#include "expect.h"

int main(int argc, char *argv[])
{
  char buffer[200];
  {
    int written = snprintf(buffer, sizeof(buffer), "Hello %s\n", "World!");
    expect(written == 13);
    expect(0 == strcmp(buffer, "Hello World!\n"));
  }
  {
    int written = snprintf(buffer, sizeof(buffer), "Hello number %d\n", 1293);
    expect(written == 18);
    expect(0 == strcmp(buffer, "Hello number 1293\n"));
  }
  
  printf("Success!\n");
  return 0;
}
