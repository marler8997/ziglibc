#ifndef _STDIO_H
#define _STDIO_H

#include "private/null.h"
#include "private/size_t.h"
#include "private/valist.h"

#define _IOFBF 0
#define _IOLBF 1
#define _IONBF 2
#define BUFSIZ 1024

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

typedef struct {
#ifdef _WIN32
  void* fd;
#else
  int fd;
#endif
  int errno;
  int eof;
} FILE;

typedef size_t fpos_t;

/* a pointer to a single object T that cannot be null */
#define SINGLE_OBJECT_PTR(T, name) T name[static 1]

#define EOF -1
#define L_tmpnam 20

extern FILE *const stdin;
extern FILE *const stdout;
extern FILE *const stderr;

int remove(const char *filename);
int rename(const char *old, const char *new);
FILE *tmpfile(void);
char *tmpnam(char *s);
int fclose(FILE *stream);
int fflush(FILE *stream);
FILE *fopen(const char *filename, const char *mode);
FILE *freopen(const char *filename, const char *mode, FILE *stream);
void setbuf(FILE *stream, char *buf);
int setvbuf(FILE *stream, char *buf, int mode, size_t size);
int fprintf(FILE *stream, const char *format, ...);
int fscanf(FILE *stream, const char *format, ...);
int printf(const char *format, ...);
int scanf(const char *format, ...);
int sprintf(char *s, const char *format, ...);
int sscanf(const char *s, const char *format, ...);
//int vfprintf(FILE *stream, const char *format, va_list arg);
int vprintf(const char *format, va_list arg);
int vsprintf(char *s, const char *format, va_list arg);
int fgetc(FILE *stream);
char *fgets(char *s, int n, FILE *stream);
int fputc(int c, FILE *stream);
int fputs(const char *s, FILE *stream);
int getc(FILE *stream);
int getchar(void);
char *gets(char *s);
int putc(int c, FILE *stream);
int putchar(int c);
int puts(const char *s);
int ungetc(int c, FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream);
int fgetpos(FILE *stream, fpos_t *pos);
int fseek(FILE *stream, long int offset, int whence);
int fsetpos(FILE *stream, const fpos_t *pos);
long int ftell(FILE *stream);
void rewind(FILE *stream);
void clearerr(FILE *stream);
int feof(FILE *stream);
int ferror(FILE *stream);
void perror(const char *s);

#if __STDC_VERSION__ >= 199901L
    int snprintf(char * restrict s, size_t n, const char * restrict format, ...);
    int vsnprintf(char *restrict s, size_t n, const char * restrict format, va_list arg);
#endif

// NOTE: this stuff is defined by POSIX, not libc, but they need
//       to live in this header
#if 1
    #define STDIN_FILENO 0
    #define STDOUT_FILENO 1
    #define STDERR_FILENO 2
    FILE *popen(const char *command, const char *mode);
    FILE *fdopen(int filedes, const char *mode);
#endif

// NOTE: this stuff is defined by linux, not libc, but they need
//       to live in this header
#if 1
    #define FOPEN_MAX 999
#endif


#endif /* _STDIO_H */
