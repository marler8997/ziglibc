#ifndef _ALLOCA_H
#define _ALLOCA_H

#include "../private/size_t.h"

void *alloca(size_t);
#define alloca __builtin_alloca

#endif /* _ALLOCA_H */
