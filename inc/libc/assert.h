#ifndef _ASSERT_H
#define _ASSERT_H

#ifdef NDEBUG
    #define assert(ignore) ((void)0)
#else
    #define assert(expression) assert(expression)
    void assert(int expression);
#endif

#endif /* _ASSERT_H */
