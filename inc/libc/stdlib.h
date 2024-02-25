#ifndef _STDLIB_H
#define _STDLIB_H

#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
// TODO: look into this value more
#define RAND_MAX 65535

#include "../private/null.h"
#include "../private/size_t.h"
#include "../private/wchar_t.h"

typedef struct { int quot, rem; } div_t;
typedef struct { long quot, rem; } ldiv_t;

double atof(const char *nptr);
int atoi(const char *nptr);
long int atol(const char *nptr);
double strtod(const char *nptr, char **endptr);
long int strtol(const char *nptr, char **endptr, int base);
unsigned long int strtoul(const char *nptr, char **endptr, int base);
int rand(void);
void srand(unsigned int seed);
void *calloc(size_t nmemb, size_t size);
void free(void *ptr);
void *malloc(size_t size);
void *realloc(void *ptr, size_t size);
void abort(void);
int atexit(void (*func)(void));
void exit(int status);
char *getenv(const char *name);
int system(const char *string);
void *bsearch(const void *key, const void *base, size_t nmemb, size_t size, int (*compar)(const void *, const void *));
void qsort(void *base, size_t nmemb, size_t size, int (*compar)(const void *, const void *));
int abs(int j);
div_t div(int numer, int denom);
long int labs(long int j);
ldiv_t ldiv(long int numer, long int denom);
int mblen(const char *s, size_t n);
int mbtowc(wchar_t *pwc, const char *s, size_t n);
int wctomb(char *s, wchar_t wchar);
size_t mbstowcs(wchar_t *pwcs, const char *s, size_t n);
size_t wcstombs(char *s, const wchar_t *pwcs, size_t n);

// NOTE: this stuff is defined by POSIX, not libc, but they need
//       to live in this header
#if 1
    int mkstemp(char *template);
#endif

// NOTE: this stuff is defined by linux, not libc, but they need
//       to live in this header
#if 1
    #define MB_CUR_MAX 1
#endif

#endif /* _STDLIB_H */
