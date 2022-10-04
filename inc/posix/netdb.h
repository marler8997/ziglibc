#ifndef _NETDB_H
#define _NETDB_H

#include "private/socklen_t.h"

struct hostent {
  char *h_name;
  char **h_aliases;
  int h_addrtype;
  int h_length;
  char **h_addr_list;
};

struct hostent *gethostbyaddr(const void *addr, socklen_t len, int type);
struct hostent *gethostbyname(const char *name);

#endif /* _NETDB_H */
