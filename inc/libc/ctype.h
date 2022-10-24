#ifndef _CTYPE_H
#define _CTYPE_H

int isalnum(int c);
int isalpha(int c);
int iscntrl(int c);
int isdigit(int c);
int isgraph(int c);
int islower(int c);
int isprint(int c);
int ispunct(int c);
int isspace(int c);
int isupper(int c);
int isxdigit(int c);
int tolower(int c);
int toupper(int c);

#if __STDC_VERSION__ >= 199901L
    int isblank(int c);
#endif

// NOTE: this stuff is defined by POSIX, not libc, but they need
//       to live in this header
#if 1
    int isascii(int c);
    int toascii(int c);
#endif


#endif /* _CTYPE_H */
