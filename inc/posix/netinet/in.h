#ifndef _NETINET_IN_H
#define _NETINET_IN_H

#include "../../libc/private/uint8_t.h"
#include "../../libc/private/uint32_t.h"
#include "../private/sockaddr.h"

#define IPPORT_RESERVED 1024
#define IPPORT_USERRESERVED 5000

#define IPPROTO_IP 0
#define IPPROTO_TCP 6
#define IPPROTO_UDP 17

#define INADDR_ANY 0

typedef uint32_t in_addr_t;
struct in_addr {
  in_addr_t s_addr;
};

#define INADDR_LOOPBACK ((in_addr_t)0x7f000001)

// TODO: define me better
struct sockaddr_in {
  int sin_family;
  int sin_port;
  struct in_addr sin_addr;
  uint8_t sin_zero[8];
};


#endif /* _NETINET_IN_H */
