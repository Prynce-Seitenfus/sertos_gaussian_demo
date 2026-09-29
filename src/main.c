/**
 * @file main.c
 * @brief Application entry point for the real-time Gaussian Distribution demonstration.
 *
 * Demonstrates preemptive multitasking, message queues, counting semaphores,
 * mutex locks, and software timers on SertOS with zero dynamic memory allocation.
 */

#include "sertos_scheduler.h"
#include "gaussian_tasks.h"
#include "bsp_console.h"
#include <stdio.h>

/**
 * @brief Caller-allocated static stack buffer for the system Idle Task (zero OS dynamic allocation).
 */
static uint8_t s_idle_task_stack[SERTOS_CONFIG_IDLE_TASK_STACK_SIZE] __attribute__((aligned(8)));

int main(void)
{
    SertosStatus status;
    const SertosConfig sertos_cfg = {
        .tick_rate_hz         = 1000U,                       /* 1 kHz tick rate (1 ms resolution) */
        .enable_time_slicing  = true,                        /* Enable round-robin time slicing */
        .idle_task_stack      = s_idle_task_stack,           /* Static user-provisioned Idle stack */
        .idle_task_stack_size = sizeof(s_idle_task_stack),
        .tick_hook            = NULL,
        .idle_hook            = NULL
    };

    /* Initialize BSP console hardware (UART / standard I/O) */
    bsp_console_init();

    /* Initialize SertOS scheduler with dynamic runtime configuration */
    status = sertos_scheduler_init_with_config(&sertos_cfg);
    if (status != SERTOS_STATUS_OK) {
        (void)printf("FATAL: Failed to initialize SertOS scheduler (status: %d)\n", (int)status);
        return 1;
    }

    /* Initialize application tasks, queue, mutex, semaphore, and software timer */
    status = gaussian_tasks_init();
    if (status != SERTOS_STATUS_OK) {
        (void)printf("FATAL: Failed to initialize Gaussian demonstration tasks (status: %d)\n", (int)status);
        return 1;
    }

    /* Start preemptive multitasking (blocks until shutdown signal on Windows simulator) */
    sertos_scheduler_start();

    (void)printf("\n[SertOS] Gaussian Distribution Demonstration terminated cleanly.\n");
    return 0;
}
