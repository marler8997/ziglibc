#ifndef _STRING_H
#define _STRING_H

#include "private/null.h"
#include "private/size_t.h"

void *memcpy(void *s1, const void *s2, size_t n);
void *memmove(void *s1, const void *s2, size_t n);
char *strcpy(char *s1, const char *s2);
char *strncpy(char *s1, const char *s2, size_t n);
char *strcat(char *s1, const char *s2);
char *strncat(char *s1, const char *s2, size_t n);
int memcmp(const void *s1, const void *s2, size_t n);
int strcmp(const char *s1, const char *s2);
int strcoll(const char *s1, const char *s2);
int strncmp(const char *s1, const char *s2, size_t n);
size_t strxfrm(char *s1, const char *s2, size_t n);
void *memchr(const void *s, int c, size_t n);
char *strchr(const char *s, int c);
size_t strcspn(const char *s1, const char *s2);
char *strpbrk(const char *s1, const char *s2);
char *strrchr(const char *s, int c);
size_t strspn(const char *s1, const char *s2);
char *strstr(const char *s1, const char *s2);
char *strtok(char *s1, const char *s2);
void *memset(void *s, int c, size_t n);
char *strerror(int errnum);
size_t strlen(const char *s);

// TODO: I'm not sure where strsignal comes from, it might
//       be GNU-specific but the libc-test project requires it
//       so I'm just inluding it for now.
char* strsignal(int);

// NOTE: it looks like strdup is defined by posix (not libc)
//       but it needs to be in string.h defined by libc (not posix)
//       so for now I'm just including it here
char *strdup(const char *s);

#endif /* _STRING_H */
