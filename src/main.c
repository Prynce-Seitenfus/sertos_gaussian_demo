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

int main(void)
{
    SertosStatus status;

    /* Initialize SertOS scheduler and idle task */
    status = sertos_scheduler_init();
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
