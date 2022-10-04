#ifndef _STRINGS_H
#define _STRINGS_H

#include "private/locale_t.h"

int strcasecmp(const char *s1, const char *s2);
int strcasecmp_l(const char *s1, const char *s2,
                 locale_t locale);
int strncasecmp(const char *s1, const char *s2, size_t n);
int strncasecmp_l(const char *s1, const char *s2,
                  size_t n, locale_t locale);

#endif /* _STRINGS_H */
