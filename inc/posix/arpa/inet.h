#ifndef _ARPA_INET_H
#define _ARPA_INET_H

#include "../../libc/private/uint16_t.h"
#include "../../libc/private/uint32_t.h"

uint32_t htonl(uint32_t hostlong);
uint16_t htons(uint16_t hostshort);
uint32_t ntohl(uint32_t netlong);
uint16_t ntohs(uint16_t netshort);

#endif /* _ARPA_INET_H */
