#ifndef _LOCALE_H
#define _LOCALE_H

#include "private/null.h"

#define LC_ALL 6
#define LC_COLLATE 3
#define LC_CTYPE 0
#define LC_MONETARY 4
#define LC_NUMERIC 1
#define LC_TIME 2

struct lconv {
    char *decimal_point;       /* "." */
    char *thousands_sep;       /* "" */
    char *grouping;            /* "" */
    char *int_curr_symbol;     /* "" */
    char *currency_symbol;     /* "" */
    char *mon_decimal_point;   /* "" */
    char *mon_thousands_sep;   /* "" */
    char *mon_grouping;        /* "" */
    char *positive_sign;       /* "" */
    char *negative_sign;       /* "" */
    char int_frac_digits;      /* CHAR_MAX */
    char frac_digits;          /* CHAR_MAX */
    char p_cs_precedes;        /* CHAR_MAX */
    char p_sep_by_space;       /* CHAR_MAX */
    char n_cs_precedes;        /* CHAR_MAX */
    char n_sep_by_space;       /* CHAR_MAX */
    char p_sign_posn;          /* CHAR_MAX */
    char n_sign_posn;          /* CHAR_MAX */
};

char *setlocale(int category, const char *locale);
struct lconv *localeconv(void);

#endif /* _LOCALE_H */
