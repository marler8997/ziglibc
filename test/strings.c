#include <assert.h>
#include <string.h>
#include <stdio.h>

static void expect(int expr)
{
  if (!expr) abort();
}

int main(int argc, char *argv[])
{
  expect(16 == strlen("this is a string"));

  expect(0 == strcmp("abc", "abc"));
  expect(0 > strcmp("abc", "abd"));
  expect(0 < strcmp("abd", "abc"));

  expect(NULL == strchr("hello", 'z'));
  {
    const char *s = "abcdef";
    expect(s + 4 == strchr(s, 'e'));
  }
  puts("Success!");
}
