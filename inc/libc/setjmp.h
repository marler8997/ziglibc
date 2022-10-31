#ifndef _SETJMP_H
#define _SETJMP_H

#include "private/noreturn.h"

/* copied from musl, x86_64 setjmp.j */
typedef unsigned long __jmp_buf[8];
typedef struct __jmp_buf_tag {
	__jmp_buf __jb;
	unsigned long __fl;
	unsigned long __ss[128/sizeof(long)];
} jmp_buf[1];

int setjmp(jmp_buf env);
__znoreturn void longjmp(jmp_buf env, int val);

#endif /* _SETJMP_H */
