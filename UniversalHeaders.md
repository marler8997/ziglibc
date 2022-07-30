Universal Headers
================================================================================

Working Backwards
--------------------------------------------------------------------------------
Creating a universal set of headers is a difficult problem.  I think we can
break it up by looking at what the final stage of header generation would look
like.

In the last stage of header generation, we'll want a list of public header file
objects where each object includes a list of all possible symbols that it could
define.  With this we'll generate the final public header files, here's an
example of what `stdio.h` might look like:

```c
#include "d/NULL"
#include "d/printf"
#include "d/FILE"
#include "d/fopen"
```

It seems like a simple way to organize things is to put every symbol in its own
file.  Within each symbol file will be a set of conditions that determine what
the definition will be if it has a definition at all.

### Defining vs Reachable Conditions

Within the symbol include files are conditions that determine what the definition
is, however, there will be some conditions that can change which header files do
or do not pull in a symbol.  For example, the `stdio.h` header could pull in
`NULL` in glibc but not on macos.  With the current design, the symbol include
file that contains the definition won't have any knowledge of what header file is
currently pulling it in.

> We could propagate that information by defining something like `INCLUDING_STDIO` and
  undefining it afterwards, but then the symbol include file guards would need to be
  smart enough to know which `INCLUDING_*` definitions affect it and allow multiple
  passes, which seems quite complicated to get right and would prevent us from getting
  some potential performance with `#pragma once`.

Instead, I think the right approach might be to allow the public header files to
support "Reachable Conditions", which are simply conditions that can be used to
filter specific symbols, i.e.

```c
#if A
#include "d/foo"
#endif
```

These Reachable Conditions could be organized in ConjuctiveNormalForm, where sets of
definitions could be organized in a tree where each "edge" of the
tree is one or more conditions, i.e.

```c
#include "d/foo"

#if A || B
    #include "d/bar"

    #if C
        #include "d/baz"
    #endif
#endif
```

Note that this would be a space-saving equivalent of a flat
data structure, where each symbol simply has a list of conditions, i.e.
```c
#if 1
    #include "d/foo"
#endif
#if A || B
    #include "d/bar"
#endif
#if (A || B) && C
    #include "d/baz"
#endif
```

It might be easier to start with the latter and then create an algorithm
to convert the latter to the former tree representation for the sake
of saving space in the headers.

How do we get there?
--------------------------------------------------------------------------------
The following is my thoughts on a data structure we could generate to prepare
for the final stage.

For every symbol we'll need to know all definition variations (i.e. `socket_t`
could be `int` or `void*`).  Every varition will be coupled with a condition
that enables it.

For example:

```c
#if __posix__
    typedef int socket_t;
#endif
#if __WIN32__
    typedef void* socket_t;
#endif
```

> NOTE: we'll want to semantically analyze macro definitions so
        we can normalize/combine similar values
