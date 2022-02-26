# ziglibc

An exploration on creating a libc implementation in Zig.

# Thoughts

I'd like a common codebase that can create libc headers that emulate various libc implementations.
For this I'd like to create a database for the libc API that includes information about features,
versions, behavior changes, etc.  From this database, headers can be generated for any combination
of parameters based on the database.

I'd also like to support static and dynamic linking.  Static linking means providing a full
implementation for all of libc and dynamic means emulating whatever libc target the project needs.

# Test Projects

The following is a list of C projects that I could use to test ziglibc with:

* Lua
* sqlite
* zlib
* Make/Autotools
* BASH
* SDL
* GTK
