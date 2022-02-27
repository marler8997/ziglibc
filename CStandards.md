# C Standards

See https://en.wikipedia.org/wiki/ANSI_C

### Timeline

* 1985: ANSI releases first draft of Standard (aka C85)
* 1986: ANSI releases second draft of Standard (aka C86)
* 1988: ANSI publishes prerelease Standard (aka C88)
* 1989: ANSI completes and ratifies the standard "X3.159-1989" "Programming Language C".
        This version is also known as "ANSI C" or "C89".
* 1990: ISO ratifies "ANSI C" as "ISO/IEC 9899:1990" with some formatting changes.
        This version is also known as "C90", which makes "C89" and "C90" essentially the same language.
* 1995: ISO publishes an extension to C90 called "Amendment 1" with "ISO/IEC 9899:1990/AMD1:1995".
        This version is also known as "C95".
* 1999: ISO and ANSI adopt "ISO/IEC 9899:1999".
        This version is also known as "C99".
* 2011: C11 ratified
* 2018: C17

### C89 (aka C90)

https://port70.net/~nsz/c/c89/c89-draft.html

### C95

* improved multi-byte and wide character support, introduces `<wchar.h>` and `<wctype.h>` and multi-byte IO
* adds digraphs
* standard macros for alternative specification operators (e.g. `and` for `&&`)
* adds `__STDC_VERSION__` macro

Preprocessor test for c95:
```c
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199409L
    /* C95 compatible source code. */
#elif defined(__STDC__)
    /* C89 compatible source code. */
#endif
```

### C99

https://port70.net/~nsz/c/c99/n1256.html

* new builtin types `long long`, `_Bool`, `_Complex` and `_Imaginary`
* static array indices
* designated initializers
* compound literals
* variable-length arrays
* flexible array members
* variadic macros
* the `restrict` keyword
* adds `stdint.h`, `tgmath.h`, `fenv.h` and `complex.h`
* inline functions
* single-line comments `//`
* ability to mix declarations and code
* universal character names in identifiers
* removed several dangerous C89 language features like implicit function declarations and implicit `int`

### C11

https://port70.net/~nsz/c/c11/n1570.html

* improved unicode support
* type-generic expressions using the new `_Generic` keyword
* cross-platform multi-threading API `threads.h`
* atomic types support in langauge and library in `stdatomic.h`

### C17

* addresses defects in C11 without adding new features
