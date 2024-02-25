The purpose of the private subdirectory is to hold headers that are private
to the std headers (not accessible outside the std headers).

I'm currently trying to organize the headers in such a way that none of the
public headers depend on each other.  This means that if one public header
depends on something from another public header (i.e. stdio.h needs size_t
from stdlib.h), then that common "thing" is moved to a private header
included by both public headers.
