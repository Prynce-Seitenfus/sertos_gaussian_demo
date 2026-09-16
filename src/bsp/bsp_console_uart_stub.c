/**
 * @file bsp_console_uart_stub.c
 * @brief Bare-metal MCU UART implementation of console abstraction for ARM Cortex-M / QEMU.
 *
 * Implements serial terminal output and keyboard input via CMSDK APB UART
 * on ARM Cortex-M33 (e.g. QEMU MPS2-AN505 at base 0x40200000).
 */

#if defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__thumb__) || defined(__riscv)

#include "bsp_console.h"
#include <stdint.h>
#include <stddef.h>

#ifndef UART0_BASE
#define UART0_BASE          (0x40200000U)
#endif

#define UART0_DATA          (*(volatile uint32_t*)(UART0_BASE + 0x00U))
#define UART0_STATE         (*(volatile uint32_t*)(UART0_BASE + 0x04U))
#define UART0_CTRL          (*(volatile uint32_t*)(UART0_BASE + 0x08U))
#define UART0_BAUDDIV       (*(volatile uint32_t*)(UART0_BASE + 0x10U))

#define UART_STATE_TXFULL   (1U << 0U)
#define UART_STATE_RXFULL   (1U << 1U)
#define UART_CTRL_TXEN      (1U << 0U)
#define UART_CTRL_RXEN      (1U << 1U)

void bsp_console_init(void)
{
    /* Configure CMSDK APB UART baud rate divisor and enable TX and RX */
    UART0_BAUDDIV = 16U;
    UART0_CTRL = UART_CTRL_TXEN | UART_CTRL_RXEN;
}

void bsp_console_putc(char c)
{
    uint32_t timeout = 200000U;
    while (((UART0_STATE & UART_STATE_TXFULL) != 0U) && (timeout > 0U)) {
        timeout--;
    }
    if (timeout > 0U) {
        UART0_DATA = (uint32_t)(uint8_t)c;
    }
}

void bsp_console_puts(const char* str)
{
    if (str != NULL) {
        while (*str != '\0') {
            if (*str == '\n') {
                bsp_console_putc('\r');
                bsp_console_putc('\n');
                /* Brief pacing delay per line to allow host serial backend to flush */
                for (volatile uint32_t d = 0U; d < 2000U; d++) {
                    __asm__ volatile ("nop");
                }
            } else {
                bsp_console_putc(*str);
            }
            str++;
        }
    }
}

bool bsp_console_poll_char(char* out_char)
{
    if (out_char == NULL) {
        return false;
    }

    if ((UART0_STATE & UART_STATE_RXFULL) != 0U) {
        *out_char = (char)(UART0_DATA & 0xFFU);
        return true;
    }

    return false;
}

void bsp_console_cleanup(void)
{
    /* Optional flush / restore operations */
}

#endif /* defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__thumb__) || defined(__riscv) */
