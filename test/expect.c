#include <stdlib.h>
#include <stdio.h>

void on_expect_fail(const char *expression, const char *file, int line, const char *func)
{
    fprintf(stderr, "%s:%d: expect failure '%s' in function '%s'\n", file, line, expression, func);
    exit(0xff);
}
