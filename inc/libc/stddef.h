#ifndef _STDDEF_H
#define _STDDEF_H

#include "private/null.h"
#include "private/sizet.h"
#include "private/wchart.h"

// TODO: look into this more
typedef int ptrdiff_t;

#define offsetof(type, member) __builtin_offsetof(type, member)

#endif /* _STDDEF_H */
