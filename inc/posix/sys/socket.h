#ifndef _SYS_SOCKET_H
#define _SYS_SOCKET_H

#include "../private/ssize_t.h"
#include "../private/sockaddr.h"

#define SOCK_STREAM 1
#define SOCK_DGRAM 2

#define AF_INET 2
#define PF_INET AF_INET

int socket(int domain, int type, int protocol);

// todo: define me better
typedef int socklen_t;
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
ssize_t sendto(int socket, const void *message, size_t len,
               int flags, const struct sockaddr *dest_addr,
               socklen_t dest_len);
ssize_t recvfrom(int socket, void *restrict buffer, size_t length,
                 int flag, struct sockaddr *restrict address,
                 socklen_t *restrict address_len);
#define SHUT_RD 0
#define SHUT_WR 1
#define SHUT_RDWR 2
int shutdown(int socket, int how);

#endif /* _SYS_SOCKET_H */
