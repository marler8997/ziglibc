#include <stdio.h>

#include "expect.h"

int main(int argc, char *argv[])
{
  char buffer[200];
  {
    int written = snprintf(buffer, sizeof(buffer), "Hello %s\n", "World!");
    expect(written == 13);
    buffer[13] = 0;
    expect(0 == strcmp(buffer, "Hello World!\n"));
  }
  
  printf("Success!\n");
  return 0;
}
