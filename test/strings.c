#include <assert.h>
#include <string.h>
#include <stdio.h>

#include "expect.h"

int main(int argc, char *argv[])
{
  expect(16 == strlen("this is a string"));

  expect(0 == strcmp("abc", "abc"));
  expect(0 > strcmp("abc", "abd"));
  expect(0 < strcmp("abd", "abc"));

  expect(0 == strncmp("abc", "abc", 3));
  expect(0 == strncmp("abc", "abc", 2));
  expect(0 == strncmp("abc", "abd", 2));
  expect(0 > strncmp("abc", "abd", 3));
  expect(0 == strncmp("abd", "abc", 2));
  expect(0 < strncmp("abd", "abc", 3));

  expect(NULL == strchr("hello", 'z'));
  {
    const char *s = "abcdef";
    expect(s + 4 == strchr(s, 'e'));
  }

  puts("Success!");
}
