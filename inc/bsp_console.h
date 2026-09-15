/**
 * @file bsp_console.h
 * @brief Board/Platform support package console I/O abstraction.
 *
 * Provides a uniform, zero-overhead interface for terminal character output
 * and non-blocking input across Windows host, POSIX host, and MCU targets.
 */

#ifndef BSP_CONSOLE_H
#define BSP_CONSOLE_H

#include <stdbool.h>
#include <stddef.h>

/**
 * @brief Initializes the console hardware or host terminal subsystem.
 *
 * On Windows, enables ANSI virtual terminal processing.
 * On bare metal, initializes UART peripheral.
 */
void bsp_console_init(void);

/**
 * @brief Transmits a single character to the console.
 *
 * @param c Character byte to transmit.
 */
void bsp_console_putc(char c);

/**
 * @brief Transmits a null-terminated string to the console.
 *
 * @param str Null-terminated string buffer.
 */
void bsp_console_puts(const char* str);

/**
 * @brief Polls the console for an incoming character in a non-blocking manner.
 *
 * @param[out] out_char Pointer to variable receiving the character if available.
 * @return true if a character was read, false if no input is pending.
 */
bool bsp_console_poll_char(char* out_char);

/**
 * @brief Restores original console settings upon application termination.
 */
void bsp_console_cleanup(void);

#endif /* BSP_CONSOLE_H */
