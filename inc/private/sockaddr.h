#ifndef _PRIVATE_SOCKADDR_H
#define _PRIVATE_SOCKADDR_H

#include "sa_family_t.h"

// TODO: define me better
struct sockaddr {
  sa_family_t sa_family;
  char reserved[100];
};

#endif /* _PRIVATE_SOCKADDR_H */
