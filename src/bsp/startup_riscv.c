/**
 * @file startup_riscv.c
 * @brief Minimal bare-metal C startup and system calls for RISC-V RV32I on QEMU.
 *
 * Implements _start entry point, BSS zero-initialization, stack setup,
 * and minimal Newlib-nano syscall stubs.
 */

#if defined(__riscv)

#include <stdint.h>
#include <stddef.h>
#include <sys/stat.h>
#include <errno.h>

/* Linker script symbols */
extern uint32_t _estack;
extern uint32_t _sbss;
extern uint32_t _ebss;
extern uint32_t end;

/* Application main and console interfaces */
extern int main(void);
extern void bsp_console_putc(char c);
extern void bsp_console_cleanup(void);

/**
 * @brief Boot entry point executed by QEMU virt machine.
 */
void _start(void) __attribute__((section(".text.init"), naked));
void _start(void)
{
    __asm__ volatile (
        ".option push\n"
        ".option norelax\n"
        "la      gp, __global_pointer$\n"
        ".option pop\n"
        "la      sp, _estack\n"
        "la      t0, _sbss\n"
        "la      t1, _ebss\n"
        "1:\n"
        "bge     t0, t1, 2f\n"
        "sw      zero, 0(t0)\n"
        "addi    t0, t0, 4\n"
        "j       1b\n"
        "2:\n"
        "call    main\n"
        "call    bsp_console_cleanup\n"
        "3:\n"
        "wfi\n"
        "j       3b\n"
    );
}

/* Minimal POSIX syscall stubs for Newlib-nano execution */

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
    bsp_console_cleanup();
    while (1) {
        __asm__ volatile ("wfi");
    }
}

#endif /* defined(__riscv) */
