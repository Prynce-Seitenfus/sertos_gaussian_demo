/**
 * @file bsp_console_posix.c
 * @brief POSIX host implementation of the console abstraction.
 *
 * Configures termios non-canonical mode, handles non-blocking terminal reads,
 * and manages ANSI cursor visibility for Linux and macOS environments.
 */

#if !defined(_WIN32)

#include "bsp_console.h"
#include <stdio.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>

static struct termios s_orig_termios;
static bool s_termios_saved = false;

void bsp_console_init(void)
{
    struct termios raw;
    int flags;

    if (tcgetattr(STDIN_FILENO, &s_orig_termios) == 0) {
        s_termios_saved = true;
        raw = s_orig_termios;
        raw.c_lflag &= (tcflag_t)~(ECHO | ICANON);
        raw.c_cc[VMIN] = 0;
        raw.c_cc[VTIME] = 0;
        (void)tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    }

    /* Set non-blocking I/O flag on stdin */
    flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    if (flags >= 0) {
        (void)fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
    }

    /* Hide cursor */
    (void)fputs("\033[?25l", stdout);
    (void)fflush(stdout);
}

void bsp_console_putc(char c)
{
    (void)putchar((int)c);
}

void bsp_console_puts(const char* str)
{
    if (str != NULL) {
        (void)fputs(str, stdout);
        (void)fflush(stdout);
    }
}

bool bsp_console_poll_char(char* out_char)
{
    char ch;
    ssize_t n;

    if (out_char == NULL) {
        return false;
    }

    n = read(STDIN_FILENO, &ch, 1);
    if (n > 0) {
        *out_char = ch;
        return true;
    }

    return false;
}

void bsp_console_cleanup(void)
{
    (void)fputs("\033[?25h\033[0m\n", stdout);
    (void)fflush(stdout);

    if (s_termios_saved) {
        (void)tcsetattr(STDIN_FILENO, TCSANOW, &s_orig_termios);
        s_termios_saved = false;
    }
}

#endif /* !defined(_WIN32) */
