# ziglibc

An exploration on creating a libc implementation in Zig.

"libc" includes implementations for the C Standard and the Posix Standard.

# How to Use

This is a little ugly and should change but I'm documenting it here for the adventurous.

You can use ziglibc by running `zig build` on this repository.  Then add these arguments
to your `zig cc` command line:

```
zig cc \
    -nostdlib \
    -I PATH_TO_ZIGLIBC_SRC/inc/libc \
    -I PATH_TO_ZIGLIBC_SRC/inc/posix \
    -I PATH_TO_ZIGLIBC_SRC/inc/linux \
    -L PATH_TO_ZIGLIBC_INSTALL/lib \
    -lstart \
    -lc
```

Currently builds with zig version `0.11.0-dev.3312+ab37ab33c`.

# Thoughts

I'd like a common codebase that can create libc headers that emulate various libc implementations.
For this I'd like to create a database for the libc API that includes information about features,
versions, behavior changes, etc.  From this database, headers can be generated for any combination
of parameters based on the database.

I'd also like to support static and dynamic linking.  Static linking means providing a full
implementation for all of libc and dynamic means emulating whatever libc target the project needs.

# Test Projects

The following is a list of C projects that I could use to test ziglibc with:

* libc-test: https://wiki.musl-libc.org/libc-test.html (use to test our libc)
* Lua
* sqlite
* zlib
* Make/Autotools
* BASH
* SDL
* GTK
* raylib
* my morec project, tools directory
* c4
* busybox/sed
* m4 preprocessor
* ncurses
* games in ncurses?
* https://github.com/superjer/tinyc.games
