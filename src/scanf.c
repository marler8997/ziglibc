// Some of ziglibc is currently in C to have vararg support
#include <errno.h>
#include <assert.h>
#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>

struct Reader {
    // This is a dumb/slow interface, improve this
    char (*read)(struct Reader *reader);
};

enum ScanKind {
    SCAN_KIND_END,
    SCAN_KIND_TOKEN,
    SCAN_KIND_STRING,
    SCAN_KIND_HEX,
    SCAN_KIND_ERROR,
};

enum Mod {
    MOD_NONE,
    MOD_LONG,
};

struct IntStore {
    enum Mod mod;
    union {
        int i;
        long int li;
    };
};
static struct IntStore int_store_init(enum Mod mod, int val) {
    struct IntStore store;
    store.mod = mod;
    switch (mod) {
    case MOD_NONE: store.i = val; break;
    case MOD_LONG: store.li = (long int)val; break;
    default: assert(0);
    }
    return store;
}
static void int_store_mult_eq(struct IntStore *store, int mult) {
    switch (store->mod) {
    case MOD_NONE: store->i *= mult; break;
    case MOD_LONG: store->li *= (long int)mult; break;
    default: assert(0);
    }
}
static void int_store_plus_eq(struct IntStore *store, int plus) {
    switch (store->mod) {
    case MOD_NONE: store->i += plus; break;
    case MOD_LONG: store->li += (long int)plus; break;
    default: assert(0);
    }
}

struct Scan {
    enum ScanKind kind;
    union {
        struct {
            const char *start;
            const char *limit;
        } token;
        struct {
            int width;
        } string;
        struct {
            enum Mod mod;
        } hex;
    };
};
static struct Scan create_scan_end() {
    struct Scan scan;
    scan.kind = SCAN_KIND_END;
    return scan;
}
static struct Scan create_scan_token(const char *start, const char *limit) {
    struct Scan scan;
    scan.kind = SCAN_KIND_TOKEN;
    scan.token.start = start;
    scan.token.limit = limit;
    return scan;
}
static struct Scan create_scan_string(int width) {
    struct Scan scan;
    scan.kind = SCAN_KIND_STRING;
    scan.string.width = width;
    return scan;
}
static struct Scan create_scan_hex(enum Mod mod) {
    struct Scan scan;
    scan.kind = SCAN_KIND_HEX;
    scan.hex.mod = mod;
    return scan;
}
static struct Scan create_scan_error() {
    struct Scan scan;
    scan.kind = SCAN_KIND_ERROR;
    return scan;
}

static int parse_width(const char **fmt)
{
    {
        char c = (*fmt)[0];
        if (c > '9' || c < '1')
            return -1;
    }

    const char *start = (*fmt);
    int width = start[0] - '0';
    while (1) {
        *fmt += 1;
        char c = (*fmt)[0];
        if (c > '9' || c < '0') break;
        width *= 10;
        width += (int)(c - '0');
    }

    return width;
}

static int hex_value(char c) {
    if (c < '0') return -1;
    if (c <= '9') return c - '0';
    if (c < 'A') return -1;
    if (c <= 'F') return c - 'A' + 10;
    if (c < 'a') return -1;
    if (c <= 'f') return c - 'a' + 10;
    return -1;
}

static struct Scan get_next_scan(const char **fmt) {
    for (; isspace((*fmt)[0]); *fmt += 1) { }

    char first_c = (*fmt)[0];
    if (first_c == '%' || first_c == '=') {
        *fmt += 1;

        enum Mod mod = MOD_NONE;
        if ((*fmt)[0] == 'l') {
            *fmt += 1;
            if ((*fmt)[1] == 'l') {
                *fmt += 1;
                fprintf(stderr, "scanf ll modifier not implemented\n");
                abort();
            } else {
                mod = MOD_LONG;
            }
        }

        int width = parse_width(fmt);
        char c = (*fmt)[0];
        if (c == 's') {
            *fmt += 1;
            if (mod != MOD_NONE) {
                fprintf(stderr, "scanf modifier for specifier 's' is not implemented\n");
                abort();
            }
            return create_scan_string(width);
        } else if (c == 'x' || c == 'X') {
            *fmt += 1;
            if (width != -1) {
                fprintf(stderr, "scanf width for hex specifier is not implemented\n");
                abort();
            }
            return create_scan_hex(mod);
        } else {
            fprintf(stderr, "scanf modifier or specifier '%c' is invalid or not implemented\n", c);
            abort();
        }

    } else if (first_c == 0) {
        return create_scan_end();
    } else {
        const char *start = (*fmt);
        while (1) {
            *fmt += 1;
            char c = (*fmt)[0];
            if (c == 0 || c == '%' || c == '=' || isspace(c)) break;
        }
        return create_scan_token(start, *fmt);
    }
}

// returns: the number of arguments scanned, EOF on error
static int vscanf(struct Reader *reader, const char *fmt, va_list args) {
    const char *fmt_start = fmt;
    int scan_count = 0;

    while (1) {
        struct Scan scan = get_next_scan(&fmt);
        switch (scan.kind) {
        case SCAN_KIND_END:
            return scan_count;
        case SCAN_KIND_TOKEN: {
            char c;
            do { c = reader->read(reader); } while (isspace(c));

            const char *next = scan.token.start;
            while (1) {
                if (next[0] != c) return (scan_count == 0) ? -1 : scan_count;
                next++;
                if (next >= scan.token.limit) break;
                c = reader->read(reader);
            }
            break;
        }
        case SCAN_KIND_STRING: {
            char c;
            do { c = reader->read(reader); } while (isspace(c));

            char *s_arg = va_arg(args, char *);
            int total_read = 0;
            while (c != 0) {
                s_arg[total_read] = c;
                total_read++;
                if (scan.string.width != -1 && total_read >= scan.string.width) break;
                c = reader->read(reader);
                if (isspace(c)) break;
            }
            if (total_read == 0) return (scan_count == 0) ? -1 : scan_count;
            if (total_read != 0) {
                s_arg[total_read] = 0;
            }
            scan_count++;
            break;
        }
        case SCAN_KIND_HEX: {
            char c;
            do { c = reader->read(reader); } while (isspace(c));

            struct IntStore store = int_store_init(scan.hex.mod, 0);
            int read_at_least_one = 0;
            while (1) {
                int val = hex_value(c);
                if (val == -1) break;
                read_at_least_one = 1;
                int_store_mult_eq(&store, 16);
                int_store_plus_eq(&store, val);
                c = reader->read(reader);
            }
            if (!read_at_least_one) return (scan_count == 0) ? -1 : scan_count;
            switch (store.mod) {
            case MOD_NONE: *va_arg(args, int*) = store.i; break;
            case MOD_LONG: *va_arg(args, long int*) = store.li; break;
            default: assert(0);
            }
            scan_count++;
            break;
        }
        case SCAN_KIND_ERROR:
            return -1;
        default:
            fprintf(stderr, "codebug: unhandled scan kind %d\n", scan.kind);
            abort();
        }
    }
}

struct FixedReader {
    struct Reader base;
    const char *buf;
};
char fixedReaderRead(struct Reader *base) {
  struct FixedReader *reader = (struct FixedReader*)base;
  const char c = reader->buf[0];
  if (c) {
      reader->buf += 1;
  }
  return c;
}

int sscanf(const char *s, const char *fmt, ...) {
  struct FixedReader reader;
  reader.base.read = fixedReaderRead;
  reader.buf = s;
  va_list args;
  va_start(args, fmt);
  int result = vscanf(&reader.base, fmt, args);
  va_end(args);
  return result;
}