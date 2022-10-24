#ifndef _LIMITS_AND_FLOAT_SHARED_H
#define _LIMITS_AND_FLOAT_SHARED_H

/* maximum number of bits for smallest object that is not a bit-field (byte) */
#define CHAR_BIT 8

/* minimum value for an object of type signed char */
#define SCHAR_MIN -127

/* maximum value for an object of type signed char */
#define SCHAR_MAX 127

/*  maximum value for an object of type unsigned char */
#define UCHAR_MAX 255

/*  if the 'char' type is unsigned */
#define CHAR_MIN 0
#define CHAR_MAX UCHAR_MAX
/* if the 'char' type is signed */
/* #define CHAR_MIN SCHAR_MIN */
/* #define CHAR_MAX SCHAR_MAX */

/*  maximum number of bytes in a multibyte character, for any supported locale MB_LEN_MAX 1 */
/*  for now we assume wchar_t (multibyte characters) are 4 bytes */
#define MB_LEN_MAX 4

/* minimum value for an object of type short int */
#define SHRT_MIN -32767

/* maximum value for an object of type short int */
#define SHRT_MAX 32767

/* maximum value for an object of type unsigned short int */
#define USHRT_MAX 65535

/* minimum value for an object of type int */
/* assuming 32-bit int for now */
#define INT_MIN -2147483648

/* maximum value for an object of type int */
/* assuming 32-bit int for now */
#define INT_MAX 2147483647

/* maximum value for an object of type unsigned int */
/* assuming 32-bit unsigned for now */
#define UINT_MAX 0xffffffffU

#ifdef _WIN32
    #define LONG_MIN (-2147483648L)
    #define LONG_MAX (0x7fffffffL)
    #define ULONG_MAX 0xffffffffUL
#else
    #define LONG_MIN (-9223372036854775808L)
    #define LONG_MAX (0x7fffffffffffffffL)
    #define ULONG_MAX 0xffffffffffffffffUL
#endif

#endif /* _LIMITS_AND_FLOAT_SHARED_H */
