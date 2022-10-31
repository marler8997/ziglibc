#ifndef _SETJMP_H
#define _SETJMP_H

typedef struct {
    void *stack_ptr;
    void *frame_ptr;
    void *return_addr;
} jmp_buf;

int setjmp(jmp_buf env);
// TODO: mark longjmp as noreturn
void longjmp(jmp_buf env, int val);

#endif /* _SETJMP_H */
