#ifndef _ARPA_INET_H
#define _ARPA_INET_H

#include "../../private/uint16_t.h"
#include "../../private/uint32_t.h"

uint32_t htonl(uint32_t hostlong);
uint16_t htons(uint16_t hostshort);
uint32_t ntohl(uint32_t netlong);
uint16_t ntohs(uint16_t netshort);

in_addr_t inet_addr(const char *cp);
char *inet_ntoa(struct in_addr in);

#endif /* _ARPA_INET_H */
