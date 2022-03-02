#include <stdio.h>

#include "expect.h"

int main(int argc, char *argv[])
{
  char buffer[200];
  expect (13 == snprintf(buffer, sizeof(buffer), "Hello %s\n", "World!"));
  expect(0 == strcmp(buffer, "Hello World!\n"));
  expect(13 == snprintf(buffer, 0, "Hello %s\n", "World!"));

  expect(18 == snprintf(buffer, sizeof(buffer), "Hello number %d\n", 1293));
  expect(0 == strcmp(buffer, "Hello number 1293\n"));
  
  printf("Success!\n");
  return 0;
}
