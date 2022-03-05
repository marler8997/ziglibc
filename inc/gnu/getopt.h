#ifndef _GETOPT_H
#define _GETOPT_H

#include "../posix/private/getopt.h"

struct option {
  const char *name;
  int has_arg;
  int *flag;
  int val;
};

int getopt_long(int argc, char *const argv[], const char *optstring, const struct option *longopts, int *longindex);
int getopt_long_only(int argc, char *const argv[], const char *optstring, const struct option *longopts, int *longindex);

#endif /* _GETOPT_H */
