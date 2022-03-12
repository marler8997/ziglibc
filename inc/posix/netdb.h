#ifndef _NETDB_H
#define _NETDB_H

struct hostent {
  char *h_name;
  char **h_aliases;
  int h_addrtype;
  int h_length;
  char **h_addr_list;
};

#endif /* _NETDB_H */
