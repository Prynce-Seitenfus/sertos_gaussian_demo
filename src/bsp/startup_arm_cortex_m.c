/**
 * @file startup_arm_cortex_m.c
 * @brief Minimal bare-metal C startup and vector table for ARM Cortex-M targets.
 *
 * Provides Reset_Handler, FPU enablement, memory initialization (.data and .bss),
 * and links SertOS SVC, PendSV, and SysTick exception handlers.
 */

#if defined(__arm__) || defined(__thumb__)

#include <stdint.h>
#include <stddef.h>
#include <sys/stat.h>
#include <errno.h>
#include "sertos_scheduler.h"

/* Linker script symbols */
extern uint32_t _estack;
extern uint32_t _sidata;
extern uint32_t _sdata;
extern uint32_t _edata;
extern uint32_t _sbss;
extern uint32_t _ebss;
extern uint32_t end;

/* Application main function */
extern int main(void);

/* SertOS assembly exception handlers */
extern void PendSV_Handler(void);
extern void SysTick_Handler(void);

void Reset_Handler(void);

void NMI_Handler(void)
{
    while (1) {
        __asm__ volatile ("wfi");
    }
}

void HardFault_Handler(void)
{
    while (1) {
        __asm__ volatile ("wfi");
    }
}

void MemManage_Handler(void)
{
    while (1) {
        __asm__ volatile ("wfi");
    }
}

void BusFault_Handler(void)
{
    while (1) {
        __asm__ volatile ("wfi");
    }
}

void UsageFault_Handler(void)
{
    while (1) {
        __asm__ volatile ("wfi");
    }
}

__attribute__((weak))
void SVC_Handler(void)
{
    while (1) {
        __asm__ volatile ("wfi");
    }
}

void DebugMon_Handler(void)
{
    while (1) {
        __asm__ volatile ("wfi");
    }
}

void Reset_Handler(void)
{
    uint32_t* src = &_sidata;
    uint32_t* dst = &_sdata;

    /* Copy .data segment from Flash to RAM */
    while (dst < &_edata) {
        *dst++ = *src++;
    }

    /* Zero fill .bss segment in RAM */
    dst = &_sbss;
    while (dst < &_ebss) {
        *dst++ = 0U;
    }

#if defined(__ARM_FP) && (__ARM_FP > 0)
    /* Enable Coprocessors CP10 & CP11 (FPU Hardware on ARMv8-M / ARMv7E-M) */
    *(volatile uint32_t*)0xE000ED88U |= (0xFU << 20);
    __asm__ volatile ("dsb \n isb");
#endif

    /* Invoke application entry */
    (void)main();

    /* Trap if main ever exits */
    while (1) {
        __asm__ volatile ("wfi");
    }
}

/* Vector table in .vectors section */
__attribute__((section(".vectors"), used))
const void* const g_vector_table[] = {
    &_estack,
    Reset_Handler,
    NMI_Handler,
    HardFault_Handler,
    MemManage_Handler,
    BusFault_Handler,
    UsageFault_Handler,
    0, 0, 0, 0,
    SVC_Handler,
    DebugMon_Handler,
    0,
    PendSV_Handler,
    SysTick_Handler
};

/* Minimal POSIX syscall stubs for Newlib-nano bare-metal execution */
extern void bsp_console_putc(char c);

int _write(int file, char* ptr, int len)
{
    (void)file;
    if (ptr != NULL) {
        for (int i = 0; i < len; i++) {
            bsp_console_putc(ptr[i]);
        }
    }
    return len;
}

int _read(int file, char* ptr, int len)
{
    (void)file;
    (void)ptr;
    (void)len;
    return 0;
}

int _close(int file)
{
    (void)file;
    return -1;
}

int _fstat(int file, struct stat* st)
{
    (void)file;
    if (st != NULL) {
        st->st_mode = S_IFCHR;
    }
    return 0;
}

int _isatty(int file)
{
    (void)file;
    return 1;
}

int _lseek(int file, int ptr, int dir)
{
    (void)file;
    (void)ptr;
    (void)dir;
    return 0;
}

int _getpid(void)
{
    return 1;
}

int _kill(int pid, int sig)
{
    (void)pid;
    (void)sig;
    errno = EINVAL;
    return -1;
}

void* _sbrk(ptrdiff_t incr)
{
    static uint8_t* s_heap_end = NULL;
    uint8_t* prev_heap_end;

    if (s_heap_end == NULL) {
        s_heap_end = (uint8_t*)&end;
    }

    prev_heap_end = s_heap_end;
    s_heap_end += incr;
    return (void*)prev_heap_end;
}

void _exit(int status)
{
    (void)status;
    while (1) {
        __asm__ volatile ("wfi");
    }
}

#endif /* defined(__arm__) || defined(__thumb__) */
