#ifndef _RESTRICT_H_
#define _RESTRICT_H_

#if __STDC_VERSION__ >= 199901L
    #define __zrestrict restrict
#else
    #define __zrestrict
#endif

#endif /* _RESTRICT_H_ */
