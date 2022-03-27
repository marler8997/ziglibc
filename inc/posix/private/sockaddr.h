#ifndef _PRIVATE_SOCKADDR_H
#define _PRIVATE_SOCKADDR_H

// TODO: define me better
struct sockaddr {
  int sa_family;
  char reserved[100];
};

#endif /* _PRIVATE_SOCKADDR_H */
