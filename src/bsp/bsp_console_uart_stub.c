/**
 * @file bsp_console_uart_stub.c
 * @brief Bare-metal MCU UART driver for ARM Cortex-M targets and QEMU.
 *
 * Provides CMSDK APB UART console I/O across ARM MPS2-AN505 (Cortex-M33),
 * MPS2-AN386 (Cortex-M4), MPS2-AN385 (Cortex-M3), and generic MCU platforms.
 */

#if defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__thumb__) || defined(__riscv)

#include "bsp_console.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define CMSDK_UART0_AN505   (0x40200000U) /* Cortex-M33 (MPS2-AN505) */
#define CMSDK_UART0_AN385   (0x40004000U) /* Cortex-M3/M4 (MPS2-AN385 / AN386) */

#define UART_DATA_OFFSET    (0x00U)
#define UART_STATE_OFFSET   (0x04U)
#define UART_CTRL_OFFSET    (0x08U)
#define UART_BAUDDIV_OFFSET (0x10U)

#define UART_STATE_TXFULL   (1U << 0U)
#define UART_STATE_RXFULL   (1U << 1U)
#define UART_CTRL_TXEN      (1U << 0U)
#define UART_CTRL_RXEN      (1U << 1U)

static volatile uint32_t* s_uart_data = (volatile uint32_t*)(CMSDK_UART0_AN505 + UART_DATA_OFFSET);
static volatile uint32_t* s_uart_state = (volatile uint32_t*)(CMSDK_UART0_AN505 + UART_STATE_OFFSET);

void bsp_console_init(void)
{
    uint32_t base = CMSDK_UART0_AN505;

#if defined(__ARM_ARCH_7M__) || defined(__ARM_ARCH_7EM__)
    base = CMSDK_UART0_AN385;
#elif defined(__ARM_ARCH_6M__)
    base = CMSDK_UART0_AN385;
#else
    base = CMSDK_UART0_AN505;
#endif

    s_uart_data  = (volatile uint32_t*)(base + UART_DATA_OFFSET);
    s_uart_state = (volatile uint32_t*)(base + UART_STATE_OFFSET);

    *(volatile uint32_t*)(base + UART_BAUDDIV_OFFSET) = 16U;
    *(volatile uint32_t*)(base + UART_CTRL_OFFSET) = UART_CTRL_TXEN | UART_CTRL_RXEN;
}

void bsp_console_putc(char c)
{
    if (s_uart_data != NULL) {
        *s_uart_data = (uint32_t)(uint8_t)c;
    }
}

void bsp_console_puts(const char* str)
{
    if (str != NULL) {
        while (*str != '\0') {
            if (*str == '\n') {
                bsp_console_putc('\r');
                bsp_console_putc('\n');
            } else {
                bsp_console_putc(*str);
            }
            str++;
        }
    }
}

bool bsp_console_poll_char(char* out_char)
{
    if ((out_char == NULL) || (s_uart_state == NULL) || (s_uart_data == NULL)) {
        return false;
    }

    if ((*s_uart_state & UART_STATE_RXFULL) != 0U) {
        *out_char = (char)(*s_uart_data & 0xFFU);
        return true;
    }

    return false;
}

void bsp_console_cleanup(void)
{
    /* Trigger clean QEMU exit via AIRCR system reset (with -no-reboot) */
    *(volatile uint32_t*)0xE000ED0CU = 0x05FA0000U | (1U << 2U);
    while (1) {
        __asm__ volatile ("wfi");
    }
}

#endif /* defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__thumb__) || defined(__riscv) */
