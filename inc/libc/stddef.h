#ifndef _STDDEF_H
#define _STDDEF_H

#include "private/null.h"
#include "private/size_t.h"
#include "private/wchar_t.h"
#include "private/_zig_isize.h"

typedef _zig_isize ptrdiff_t;

#define offsetof(type, member) __builtin_offsetof(type, member)

#endif /* _STDDEF_H */
