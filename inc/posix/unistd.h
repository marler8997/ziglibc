#ifndef _UNISTD_H
#define _UNISTD_H

extern char *optarg;
extern int opterr, optind, optopt;
int getopt(int, char * const [], const char *);

#endif /* _UNISTD_H */
