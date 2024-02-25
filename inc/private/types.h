#ifndef _WIN32_PRIVATE_TYPES_H
#define _WIN32_PRIVATE_TYPES_H

#include "/private/int32_t.h"

#define _nullterminated

typedef int BOOL;
typedef void *PVOID;
typedef const void *LPCVOID;
typedef int32_t DWORD;
typedef char CHAR;
typedef CHAR *LPSTR;
typedef _nullterminated const char *LPCSTR;
typedef void *HMODULE;
typedef PVOID HANDLE;

#ifdef UNICODE
    typedef LPWSTR LPTSTR;
#else
    typedef LPSTR LPTSTR;
#endif

#endif /* _WIN32_PRIVATE_TYPES_H */
