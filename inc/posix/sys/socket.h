#ifndef _SYS_SOCKET_H
#define _SYS_SOCKET_H

#include "../../libc/private/restrict.h"
#include "../../libc/private/size_t.h"
#include "../private/ssize_t.h"
#include "../private/socklen_t.h"
#include "../private/sockaddr.h"

#define SOCK_STREAM 1
#define SOCK_DGRAM 2

/* TODO: this probably changes per platform */
#define AF_UNIX 1
#define AF_INET 2
#define PF_INET AF_INET

/* NOTE: this can differ on some architectures */
#define SOL_SOCKET 1

/* NOTE: these can differ on some architectures */
#define SO_KEEPALIVE 9
#define SO_SNDBUF 7

int socket(int domain, int type, int protocol);

int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
int getsockopt(int socket, int level, int option_name,
               void *__zrestrict option_value, socklen_t *__zrestrict option_len);
int setsockopt(int socket, int level, int option_name,
               const void *option_value, socklen_t option_len);

int getpeername(int socket, struct sockaddr *__zrestrict address,
    socklen_t *__zrestrict address_len);
int getsockname(int socket, struct sockaddr *__zrestrict address,
    socklen_t *__zrestrict address_len);

int connect(int socket, const struct sockaddr *address, socklen_t address_len);
ssize_t sendto(int socket, const void *message, size_t len,
               int flags, const struct sockaddr *dest_addr,
               socklen_t dest_len);
ssize_t recv(int socket, void *buffer, size_t length, int flags);
ssize_t recvfrom(int socket, void *__zrestrict buffer, size_t length,
                 int flag, struct sockaddr *__zrestrict address,
                 socklen_t *__zrestrict address_len);
#define SHUT_RD 0
#define SHUT_WR 1
#define SHUT_RDWR 2
int shutdown(int socket, int how);

#endif /* _SYS_SOCKET_H */
