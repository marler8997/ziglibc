#ifndef _ARGP_H
#define _ARGP_H

#include "../libc/private/restrict.h"

/* according to the GNU headers, error_t may be available in errno.h depending on the OS
   for now we'll just define it here */
typedef int error_t;

struct argp_option {
    const char *name;
    int key;
    const char *arg;
    int flags;
    const char *doc;
    int group;
};

#define OPTION_ARG_OPTIONAL 0x1
#define OPTION_ALIAS 0x2

#define ARGP_KEY_END 0x1000001
#define ARGP_KEY_ARGS 0x1000006
#define ARGP_KEY_NO_ARGS 0x1000002

#define ARGP_ERR_UNKNOWN 999 /* TODO: what to put here? */

struct argp_state {
    int argc;
    char **argv;
    int next;
    unsigned flags;
    unsigned arg_num;
    void *input;
};

typedef error_t (*argp_parser_t)(int key, char *arg, struct argp_state *state);

struct argp {
    const struct argp_option *options;
    argp_parser_t parser;
    const char *args_doc;
    const char *doc;
    const struct argp_child *children;
    char *(*help_filter)(int key, const char *text, void *input);
    const char *argp_domain;
};

void argp_usage(const struct argp_state *);
error_t argp_parse(
    const struct argp *__zrestrict argp,
    int argc,
    char **__zrestrict argv,
    unsigned flags,
    int *__zrestrict arg_index,
    void *__zrestrict input);

#endif /* _ARGP_H */
