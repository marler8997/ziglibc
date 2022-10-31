#include <setjmp.h>
#include <stdio.h>

void do_longjmp(jmp_buf env, int val)
{
    //fprintf(stderr, "longjmp val=%d\n", val);
    longjmp(env, val);
}

int main(int argc, char *argv[])
{
    jmp_buf env;
    int result = setjmp(env);
    //fprintf(stderr, "setjmp returned %d\n", result);
    if (result == 0) {
        do_longjmp(env, 1);
    } else if (result == 1) {
        printf("Success!\n");
        return 0;
    }
    fprintf(stderr, "should never get here\n");
    return 0xff;
}
