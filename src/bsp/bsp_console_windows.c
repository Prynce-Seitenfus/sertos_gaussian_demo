/**
 * @file bsp_console_windows.c
 * @brief Windows host implementation of the console abstraction.
 *
 * Configures Win32 virtual terminal processing (ANSI escape support),
 * handles non-blocking keyboard queries via _kbhit() / _getch(), and manages
 * terminal cursor visibility.
 */

#include "bsp_console.h"
#include <windows.h>
#include <conio.h>
#include <stdio.h>

/**
 * @brief Saved original console output mode for restoration upon exit.
 */
static DWORD s_original_out_mode = 0U;
static DWORD s_original_in_mode = 0U;
static bool s_mode_saved = false;
static HANDLE s_stdout_handle = INVALID_HANDLE_VALUE;
static HANDLE s_stdin_handle = INVALID_HANDLE_VALUE;

void bsp_console_init(void)
{
    DWORD mode = 0U;

    s_stdout_handle = GetStdHandle(STD_OUTPUT_HANDLE);
    if (s_stdout_handle != INVALID_HANDLE_VALUE) {
        if (GetConsoleMode(s_stdout_handle, &mode)) {
            s_original_out_mode = mode;
            mode |= (DWORD)ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            (void)SetConsoleMode(s_stdout_handle, mode);
        }
    }

    s_stdin_handle = GetStdHandle(STD_INPUT_HANDLE);
    if (s_stdin_handle != INVALID_HANDLE_VALUE) {
        if (GetConsoleMode(s_stdin_handle, &mode)) {
            s_original_in_mode = mode;
            s_mode_saved = true;
            /* Disable QuickEdit mode so mouse clicks do not freeze console execution */
            mode &= ~((DWORD)0x0040U); /* ENABLE_QUICK_EDIT_MODE */
            mode |= (DWORD)0x0080U;  /* ENABLE_EXTENDED_FLAGS */
            (void)SetConsoleMode(s_stdin_handle, mode);
        }
    }

    /* Hide cursor for smooth visual dashboard rendering */
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
    if (out_char == NULL) {
        return false;
    }

    if (_kbhit() != 0) {
        *out_char = (char)_getch();
        return true;
    }

    return false;
}

void bsp_console_cleanup(void)
{
    /* Restore cursor and clear text attributes */
    (void)fputs("\033[?25h\033[0m\n", stdout);
    (void)fflush(stdout);

    if (s_mode_saved) {
        if (s_stdout_handle != INVALID_HANDLE_VALUE) {
            (void)SetConsoleMode(s_stdout_handle, s_original_out_mode);
        }
        if (s_stdin_handle != INVALID_HANDLE_VALUE) {
            (void)SetConsoleMode(s_stdin_handle, s_original_in_mode);
        }
        s_mode_saved = false;
    }
}
