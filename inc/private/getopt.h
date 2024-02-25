#ifndef _PRIVATE_GETOPT_H
#define _PRIVATE_GETOPT_H

extern char *optarg;
extern int opterr, optind, optopt;
int getopt(int, char * const [], const char *);

#endif /* _PRIVATE_GETOPT_H */
