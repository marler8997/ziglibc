#include <errno.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>

#include "expect.h"

#define test(expected_return, expected_errno, str, fmt, ...) do {       \
        errno = 0;                                                      \
        expect(expected_return == sscanf(str, fmt, ##__VA_ARGS__));     \
        expect(expected_errno == errno);                                \
    } while (0)

int main(int argc, char *argv[])
{
    int i;
    long int li;
    char buf_3[3];
    
    test(0, 0, "abc", "abc");
    //test(-1, EINVAL, "abc", "abc%0s", buf);

    test(-1, 0, "abc", "abc%2s", buf_3);
    test(1, 0, "abcd", "abc%2s", buf_3);
    expect(0 == strcmp("d", buf_3));
    test(1, 0, "abc d", "abc%2s", buf_3);
    expect(0 == strcmp("d", buf_3));
    test(1, 0, "abcde", "abc%2s", buf_3);
    expect(0 == strcmp("de", buf_3));
    test(1, 0, "abcdef", "abc%2s", buf_3);
    expect(0 == strcmp("de", buf_3));

    test(1, 0, "123af0", "%x", &i);
    expect(0x123af0 == i);
    test(1, 0, "   123af0", "%x", &i);
    expect(0x123af0 == i);
    test(1, 0, "f019", "%lx", &li);
    expect(0xf019 == li);

    test(1, 0, "a bc", "a %2s", buf_3);
    test(1, 0, "a a402", "a %lx", &li);
    expect(0xa402 == li);
    test(1, 0, "a b c9f2", "a b %lx", &li);
    expect(0xc9f2 == li);
    test(1, 0, "a bd594", "a b%lx", &li);
    expect(0xd594 == li);
    test(2, 0, "a bc 0x820", "a %2s 0x%lx", buf_3, &li);
    expect(0 == strcmp("bc", buf_3));
    expect(0x820 == li);

    puts("Success!");
    return 0;
}
