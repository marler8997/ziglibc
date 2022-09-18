#ifndef _SETJMP_H
#define _SETJMP_H

typedef struct {
    int placeholder;
} jmp_buf;

int setjmp(jmp_buf env);
void longjmp(jmp_buf env, int val);

#endif /* _SETJMP_H */
