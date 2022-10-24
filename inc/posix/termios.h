#ifndef _TERMIOS_H
#define _TERMIOS_H

typedef unsigned char cc_t;
typedef unsigned tcflag_t;

#define NCSS 32

struct termios {
    tcflag_t c_iflag;
    tcflag_t c_oflag;
    tcflag_t c_cflag;
    tcflag_t c_lflag;
    cc_t c_cc[NCSS];
};

/* NOTE: these can change depending on platform */

#define VMIN 6
#define VTIME 5

/* Input Modes */
#define BRKINT 0x0002
#define INPCK  0x0010
#define ISTRIP 0x0020
#define ICRNL  0x0100
#define IXON   0x0400

#define OPOST  0x0001

#define CS8    0x0030

/* Local Modes */
#define ISIG   0x0001
#define ICANON 0x0002
#define ECHO   0x0008
#define IEXTEN 0x8000

/* Attribute Selection */
#define TCSAFLUSH 2

int tcgetattr(int, struct termios *);
int tcsetattr(int fildes, int optional_actions, const struct termios *termios_p);

/* I think these definitions are specific to linux but go in termios.h */
#if 1
    #define TIOCGWINSZ 0x5413
    struct winsize {
        unsigned short ws_row;
        unsigned short ws_col;
        unsigned short ws_xpixel;
        unsigned short ws_ypixel;
    };    
#endif

#endif /* _TERMIOS_H */
