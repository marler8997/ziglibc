#ifndef _MATH_H
#define _MATH_H

#define HUGE_VAL ((double)INFINITY)
#define HUGE_VALF ((float)INFINITY)
#define HUGE_VALL ((long double)INFINITY)

double acos(double x);
double asin(double x);
double atan(double x);
double atan2(double y, double x);
double cos(double x);
double sin(double x);
double tan(double x);
double cosh(double x);
double sinh(double x);
double tanh(double x);
double exp(double x);
double frexp(double value, int *exp);
double ldexp(double x, int exp);
double log(double x);
double log10(double x);
double modf(double value, double *iptr);
double pow(double x, double y);
double sqrt(double x);
double ceil(double x);
double fabs(double x);
double floor(double x);
double fmod(double x, double y);

#if __STDC_VERSION__ >= 199901L
    #define INFINITY __builtin_inff()
    double log2(double x);
    float log2f(float x);
    long double log2l(long double x);
#endif

#endif /* _MATH_H */
