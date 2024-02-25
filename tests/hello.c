#include <stdio.h>

int main(int argc, char *argv[])
{
  // NOTE: passing NULL to puts is undefined behavior
  //puts(0);
  if (EOF == puts("Hello")) {
    return -1;
  }
  return 0;
  //printf("Hello\n");
}
