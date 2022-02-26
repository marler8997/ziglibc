#ifndef _STDARG_H
#define _STDARG_H

#include "private/valist.h"

#define va_start(ap, parmN) __builtin_va_start(ap, parmN)
#define va_arg(ap, type) __builtin_va_arg(ap, type)
#define va_end(ap) __builtin_va_end(ap)

#endif /* _STDARG_H */
