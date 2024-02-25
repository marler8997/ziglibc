#ifndef _SETJMP_H
#define _SETJMP_H

#include "../private/noreturn.h"

#ifdef _WIN32
    typedef struct { void *stuff[40]; } jmp_buf;
#else
    /* copied from musl, x86_64 setjmp.j */
    typedef unsigned long __jmp_buf[8];
    typedef struct __jmp_buf_tag {
        __jmp_buf __jb;
        unsigned long __fl;
        unsigned long __ss[128/sizeof(long)];
    } jmp_buf[1];
#endif

int setjmp(jmp_buf env);
__znoreturn void longjmp(jmp_buf env, int val);

#endif /* _SETJMP_H */
