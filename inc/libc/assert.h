#ifndef _ASSERT_H
#define _ASSERT_H

#ifdef NDEBUG
    #define assert(ignore) ((void)0)
#else
    #define assert(expression) ((void)((expression) || (__assert_fail(#expression, __FILE__, __LINE__, __func__),0)))
    // TODO: mark __assert_fail as noreturn
    void __assert_fail(const char *expression, const char *file, int line, const char *func);
#endif

#endif /* _ASSERT_H */
