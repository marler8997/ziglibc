#ifndef _GLOB_H
#define _GLOB_H

typedef struct {
    size_t gl_pathc;
    char **gl_pathv;
    size_t gl_offs;
} glob_t;
int glob(
    const char *restrict pattern,
    int flags,
    int(*errfunc)(const char *epath, int eerrno),
    glob_t *restrict pglob);
void globfree(glob_t *pglob);

// These are GNU extensions but go in the glob.h header file
#if 1
    typedef char * __ptr_t;
#endif


#endif /* _GLOB_H */
