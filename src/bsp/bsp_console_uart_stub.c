/**
 * @file bsp_console_uart_stub.c
 * @brief Bare-metal MCU UART driver for ARM Cortex-M and RISC-V targets on QEMU.
 *
 * Provides CMSDK APB UART console I/O for ARM MPS2/MPS3 platforms, and
 * standard NS16550A UART console I/O for RISC-V virt platforms.
 */

#if defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__thumb__) || defined(__riscv)

#include "bsp_console.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if defined(__riscv)

/* QEMU virt NS16550A UART base address */
#define RISCV_UART_BASE         (0x10000000U)

void bsp_console_init(void)
{
    volatile uint8_t* const uart = (volatile uint8_t*)RISCV_UART_BASE;

    /* Disable all UART interrupts */
    uart[1] = 0x00U;

    /* Enable DLAB (Divisor Latch Access Bit) to configure baud rate */
    uart[3] = 0x80U;

    /* Set baud divisor (DLL = 0x03, DLM = 0x00 for 38400 baud at 1.8432 MHz) */
    uart[0] = 0x03U;
    uart[1] = 0x00U;

    /* 8 bits, no parity, 1 stop bit, clear DLAB */
    uart[3] = 0x03U;

    /* Enable FIFO, clear TX/RX FIFOs, 14-byte threshold (0xC7) */
    uart[2] = 0xC7U;

    /* Modem Control: DTR (bit 0) | RTS (bit 1) | OUT2 (bit 3) = 0x0B */
    uart[4] = 0x0BU;
}

void bsp_console_putc(char c)
{
    volatile uint8_t* const uart = (volatile uint8_t*)RISCV_UART_BASE;

    /* Wait until Transmitter Holding Register Empty (LSR bit 5 = 0x20) */
    while ((uart[5] & 0x20U) == 0U) {
        /* wait */
    }
    uart[0] = (uint8_t)c;
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
    volatile uint8_t* const uart = (volatile uint8_t*)RISCV_UART_BASE;

    if (out_char == NULL) {
        return false;
    }

    /* Check Data Ready (LSR bit 0 = 0x01) */
    if ((uart[5] & 0x01U) != 0U) {
        char ch = (char)uart[0];
        if ((ch != 0) && (ch != (char)0xFF)) {
            *out_char = ch;
            return true;
        }
    }

    return false;
}

void bsp_console_cleanup(void)
{
    /* Allow UART TX buffer to flush */
    for (volatile uint32_t i = 0U; i < 200000U; i++) {
        __asm__ volatile ("nop");
    }

    /* QEMU virt test finisher device exit (FINISHER_PASS = 0x5555) */
    *(volatile uint32_t*)0x100000U = 0x5555U;

    while (1) {
        __asm__ volatile ("wfi");
    }
}

#else /* ARM Cortex-M CMSDK APB UART implementation */

#define CMSDK_UART0_AN547   (0x49303000U) /* Cortex-M55 (MPS3-AN547) */
#define CMSDK_UART0_AN505   (0x40200000U) /* Cortex-M23 / Cortex-M33 (MPS2-AN505) */
#define CMSDK_UART0_AN385   (0x40004000U) /* Cortex-M0/M0+/M3/M4/M7 (MPS2-AN385 / AN386 / AN500) */

#define UART_DATA_OFFSET    (0x00U)
#define UART_STATE_OFFSET   (0x04U)
#define UART_CTRL_OFFSET    (0x08U)
#define UART_BAUDDIV_OFFSET (0x10U)

#define UART_STATE_TXFULL   (1U << 0U)
#define UART_STATE_RXFULL   (1U << 1U)
#define UART_CTRL_TXEN      (1U << 0U)
#define UART_CTRL_RXEN      (1U << 1U)

#if defined(CONFIG_TARGET_CORTEX_M55) || defined(__ARM_ARCH_8_1M_MAIN__)
#define CMSDK_UART0_BASE    CMSDK_UART0_AN547
#elif defined(__ARM_ARCH_8M_MAIN__) || defined(__ARM_ARCH_8M_BASE__)
#define CMSDK_UART0_BASE    CMSDK_UART0_AN505
#else
#define CMSDK_UART0_BASE    CMSDK_UART0_AN385
#endif

static volatile uint32_t* s_uart_data = (volatile uint32_t*)(CMSDK_UART0_BASE + UART_DATA_OFFSET);
static volatile uint32_t* s_uart_state = (volatile uint32_t*)(CMSDK_UART0_BASE + UART_STATE_OFFSET);

void bsp_console_init(void)
{
    uint32_t base = CMSDK_UART0_BASE;

    s_uart_data  = (volatile uint32_t*)(base + UART_DATA_OFFSET);
    s_uart_state = (volatile uint32_t*)(base + UART_STATE_OFFSET);

    *(volatile uint32_t*)(base + UART_BAUDDIV_OFFSET) = 16U;
    *(volatile uint32_t*)(base + UART_CTRL_OFFSET) = UART_CTRL_TXEN | UART_CTRL_RXEN;
}

void bsp_console_putc(char c)
{
    if ((s_uart_data != NULL) && (s_uart_state != NULL)) {
        while ((*s_uart_state & UART_STATE_TXFULL) != 0U) {
            /* Wait for transmit buffer ready */
        }
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
        char ch = (char)(*s_uart_data & 0xFFU);
        if ((ch != 0) && (ch != (char)0xFF)) {
            *out_char = ch;
            return true;
        }
    }

    return false;
}

void bsp_console_cleanup(void)
{
    /* Allow UART TX buffer to flush out to host terminal */
    for (volatile uint32_t i = 0U; i < 200000U; i++) {
        __asm__ volatile ("nop");
    }

    /* Request CPU Reset via AIRCR (VECTKEY | SYSRESETREQ).
     * Under QEMU with -no-reboot, this triggers an immediate, clean emulator shutdown.
     */
    *(volatile uint32_t*)0xE000ED0CU = 0x05FA0000U | (1U << 2U);
    while (1) {
        __asm__ volatile ("wfi");
    }
}

#endif /* defined(__riscv) */

#endif /* defined(SERTOS_PORT_MCU) || defined(__arm__) || defined(__thumb__) || defined(__riscv) */
