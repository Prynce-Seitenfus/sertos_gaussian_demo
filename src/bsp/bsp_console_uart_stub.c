/**
 * @file bsp_console_uart_stub.c
 * @brief Bare-metal MCU template implementation of the console abstraction.
 *
 * Designed for embedded targets (ARM Cortex-M / RISC-V, e.g. STM32H5) using
 * hardware UART peripherals for serial terminal output and keyboard input.
 */

#if defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__riscv)

#include "bsp_console.h"

void bsp_console_init(void)
{
    /* Initialize target UART peripheral and baud rate (e.g. 115200 8N1) */
}

void bsp_console_putc(char c)
{
    /* Transmit character over UART */
    (void)c;
}

void bsp_console_puts(const char* str)
{
    if (str != NULL) {
        while (*str != '\0') {
            bsp_console_putc(*str);
            str++;
        }
    }
}

bool bsp_console_poll_char(char* out_char)
{
    /* Check UART RX status register or circular RX buffer */
    (void)out_char;
    return false;
}

void bsp_console_cleanup(void)
{
    /* Flush UART buffers if necessary */
}

#endif /* defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__riscv) */
