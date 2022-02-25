// a pointer to a single object T that cannot be null
#define SINGLE_OBJECT_PTR(T, name) T name[static 1]

#define EOF -1

int puts(SINGLE_OBJECT_PTR(const char, s));
int printf(const char *format, ...);
