#ifndef _NETINET_IN_H
#define _NETINET_IN_H

#define IPPORT_RESERVED 1024
#define IPPORT_USERRESERVED 5000

#define IPPROTO_IP 0
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17

#define INADDR_ANY 0

typedef struct {
  //uint32_t s_addr;
  int s_addr;
} in_addr_t;

#include "../private/sockaddr.h"

// TODO: define me better
struct sockaddr_in {
  int sin_family;
  int sin_port;
  in_addr_t sin_addr;
};


#endif /* _NETINET_IN_H */
