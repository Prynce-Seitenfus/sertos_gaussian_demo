/**
 * @file gaussian_tasks.c
 * @brief Implementation of tasks, timers, and synchronization primitives.
 *
 * Exercises SertOS queue, mutex, counting semaphore, and periodic software timer
 * with zero dynamic memory allocation.
 */

#include "gaussian_tasks.h"
#include "gaussian_math.h"
#include "terminal_ui.h"
#include "bsp_console.h"
#include "sertos_scheduler.h"
#include "sertos_port.h"
#include <string.h>

/**
 * @brief Static task stack memory allocations (8-byte aligned per AAPCS / x86_64).
 */
static uint8_t s_stack_ingest[GAUSSIAN_STACK_SIZE_INGESTION]   __attribute__((aligned(8)));
static uint8_t s_stack_stats[GAUSSIAN_STACK_SIZE_STATS]         __attribute__((aligned(8)));
static uint8_t s_stack_vis[GAUSSIAN_STACK_SIZE_VISUALIZER]     __attribute__((aligned(8)));
static uint8_t s_stack_input[GAUSSIAN_STACK_SIZE_INPUT]         __attribute__((aligned(8)));

/**
 * @brief Static Task Control Blocks (TCBs).
 */
static SertosTaskControlBlock s_tcb_ingest;
static SertosTaskControlBlock s_tcb_stats;
static SertosTaskControlBlock s_tcb_vis;
static SertosTaskControlBlock s_tcb_input;

/**
 * @brief Task handles.
 */
static SertosTaskHandle s_handle_ingest = NULL;
static SertosTaskHandle s_handle_stats = NULL;
static SertosTaskHandle s_handle_vis = NULL;
static SertosTaskHandle s_handle_input = NULL;

/**
 * @brief Static message queue storage buffer (512 bytes, power of 2, holds >= 32 doubles).
 */
static uint8_t s_queue_storage[512] __attribute__((aligned(8)));
static SertosQueue s_queue_obj;
static SertosQueueHandle s_queue_handle = NULL;

/**
 * @brief Static synchronization objects: Mutex and Semaphore.
 */
static SertosMutex s_mutex_obj;
static SertosMutexHandle s_mutex_handle = NULL;

static SertosSemaphore s_sem_obj;
static SertosSemHandle s_sem_handle = NULL;

/**
 * @brief Static software timer object for 50 Hz data acquisition.
 */
static SertosTimer s_timer_obj;
static SertosTimerHandle s_timer_handle = NULL;

/**
 * @brief Static batch buffer between Ingestion Engine and Statistical Engine.
 */
static double s_batch_buffer[GAUSSIAN_BATCH_SIZE];
static uint32_t s_batch_index = 0U;

/**
 * @brief Global shared state instance.
 */
static GaussianState s_app_state;

/**
 * @brief Deterministic PRNG instance.
 */
static GaussianPrng s_prng;

void gaussian_timer_acquisition_callback(SertosTimerHandle handle, void* param)
{
    double sample;
    SertosStatus status;

    (void)handle;
    (void)param;

    if (s_app_state.is_paused || s_app_state.should_terminate) {
        return;
    }

    sample = gaussian_math_sample_irwin_hall(&s_prng);

    /* Post raw sample to message queue in a non-blocking manner */
    status = sertos_queue_send(s_queue_handle, &sample, SERTOS_NO_WAIT);
    if (status != SERTOS_STATUS_OK) {
        /* Queue saturated (32 items backlog); record dropped sample */
        if (sertos_mutex_lock(s_mutex_handle, SERTOS_NO_WAIT) == SERTOS_STATUS_OK) {
            s_app_state.dropped_samples++;
            (void)sertos_mutex_unlock(s_mutex_handle);
        }
    }
}

void gaussian_task_ingestion_entry(void* param)
{
    double sample;
    uint32_t bin;
    SertosStatus status;

    (void)param;

    while (!s_app_state.should_terminate) {
        /* Block on message queue awaiting incoming sample */
        status = sertos_queue_receive(s_queue_handle, &sample, SERTOS_WAIT_FOREVER);
        if (status != SERTOS_STATUS_OK) {
            continue;
        }

        bin = gaussian_math_value_to_bin(sample);

        /* Update histogram bins and buffer raw sample into batch under mutex */
        if (sertos_mutex_lock(s_mutex_handle, SERTOS_WAIT_FOREVER) == SERTOS_STATUS_OK) {
            s_app_state.bins[bin]++;
            s_app_state.total_samples++;

            s_batch_buffer[s_batch_index] = sample;
            s_batch_index++;

            if (s_batch_index >= GAUSSIAN_BATCH_SIZE) {
                s_batch_index = 0U;
                /* Signal analytical Statistical Engine every 50 completed samples */
                (void)sertos_sem_give(s_sem_handle);
            }

            (void)sertos_mutex_unlock(s_mutex_handle);
        }
    }
}

void gaussian_task_stats_entry(void* param)
{
    double local_batch[GAUSSIAN_BATCH_SIZE];
    uint32_t i;
    SertosStatus status;

    (void)param;

    while (!s_app_state.should_terminate) {
        /* Block on batch semaphore until Ingestion signals a 50-sample batch */
        status = sertos_sem_take(s_sem_handle, SERTOS_WAIT_FOREVER);
        if (status != SERTOS_STATUS_OK) {
            continue;
        }

        /* Snapshot the 50-sample batch under mutex */
        if (sertos_mutex_lock(s_mutex_handle, SERTOS_WAIT_FOREVER) == SERTOS_STATUS_OK) {
            (void)memcpy(local_batch, s_batch_buffer, sizeof(local_batch));
            s_app_state.batch_count++;

            /* Update Welford running moments directly on raw continuous values */
            for (i = 0U; i < GAUSSIAN_BATCH_SIZE; i++) {
                welford_update(&s_app_state.stats, local_batch[i]);
            }

            (void)sertos_mutex_unlock(s_mutex_handle);
        }
    }
}

void gaussian_task_visualizer_entry(void* param)
{
    GaussianState snapshot;

    (void)param;

    terminal_ui_init();

    while (!s_app_state.should_terminate) {
        /* Periodic frame delay: 80 ms = 12.5 FPS */
        (void)sertos_scheduler_delay(GAUSSIAN_VIS_DELAY_TICKS);

        /* Capture atomic state snapshot under mutex */
        if (sertos_mutex_lock(s_mutex_handle, SERTOS_WAIT_FOREVER) == SERTOS_STATUS_OK) {
            (void)memcpy(&snapshot, &s_app_state, sizeof(GaussianState));
            (void)sertos_mutex_unlock(s_mutex_handle);
        }

        terminal_ui_render(&snapshot);

        if (snapshot.should_terminate) {
            break;
        }
    }

    terminal_ui_cleanup();
}

void gaussian_task_input_entry(void* param)
{
    char ch;

    (void)param;

    while (!s_app_state.should_terminate) {
        /* Poll console input every 50 ms */
        (void)sertos_scheduler_delay(GAUSSIAN_INPUT_DELAY_TICKS);

        if (bsp_console_poll_char(&ch)) {
            if ((ch == 'p') || (ch == 'P') || (ch == ' ')) {
                if (sertos_mutex_lock(s_mutex_handle, SERTOS_WAIT_FOREVER) == SERTOS_STATUS_OK) {
                    s_app_state.is_paused = !s_app_state.is_paused;
                    (void)sertos_mutex_unlock(s_mutex_handle);
                }
            } else if ((ch == 'r') || (ch == 'R')) {
                if (sertos_mutex_lock(s_mutex_handle, SERTOS_WAIT_FOREVER) == SERTOS_STATUS_OK) {
                    gaussian_state_reset(&s_app_state);
                    s_batch_index = 0U;
                    (void)sertos_mutex_unlock(s_mutex_handle);
                }
            } else if ((ch == 'q') || (ch == 'Q') || (ch == 27)) {
                if (sertos_mutex_lock(s_mutex_handle, SERTOS_WAIT_FOREVER) == SERTOS_STATUS_OK) {
                    s_app_state.should_terminate = true;
                    (void)sertos_mutex_unlock(s_mutex_handle);
                }
                sertos_port_stop_scheduler();
                break;
            }
        }
    }
}

SertosStatus gaussian_tasks_init(void)
{
    SertosStatus status;
    SertosTaskConfig task_cfg;
    SertosTimerConfig timer_cfg;

    gaussian_state_init(&s_app_state);
    gaussian_prng_init(&s_prng, 0x5A17C0DEU);
    s_batch_index = 0U;

    /* 1. Statically create Message Queue (depth 32 doubles) */
    status = sertos_queue_create_static(&s_queue_obj,
                                        s_queue_storage,
                                        sizeof(s_queue_storage),
                                        sizeof(double),
                                        &s_queue_handle);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* 2. Statically create Mutex */
    status = sertos_mutex_create_static(&s_mutex_obj, &s_mutex_handle);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* 3. Statically create Counting Semaphore (max 10 batches) */
    status = sertos_sem_create_counting_static(&s_sem_obj, 0U, 10U, &s_sem_handle);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* 4. Statically create 50 Hz Periodic Software Timer (20 ms interval) */
    timer_cfg.name = "AcqTimer";
    timer_cfg.period = GAUSSIAN_TIMER_PERIOD_TICKS;
    timer_cfg.is_periodic = true;
    timer_cfg.callback = gaussian_timer_acquisition_callback;
    timer_cfg.param = NULL;

    status = sertos_timer_create_static(&timer_cfg, &s_timer_obj, &s_timer_handle);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* 5. Statically create Tasks */
    /* Highest Priority: Ingestion Task */
    task_cfg.name = "Ingestion";
    task_cfg.entry_func = gaussian_task_ingestion_entry;
    task_cfg.param = NULL;
    task_cfg.priority = GAUSSIAN_PRIO_INGESTION;
    task_cfg.stack_buffer = s_stack_ingest;
    task_cfg.stack_size = sizeof(s_stack_ingest);
    status = sertos_task_create_static(&task_cfg, &s_tcb_ingest, &s_handle_ingest);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* High Priority: Statistical Engine Task */
    task_cfg.name = "Stats";
    task_cfg.entry_func = gaussian_task_stats_entry;
    task_cfg.param = NULL;
    task_cfg.priority = GAUSSIAN_PRIO_STATS;
    task_cfg.stack_buffer = s_stack_stats;
    task_cfg.stack_size = sizeof(s_stack_stats);
    status = sertos_task_create_static(&task_cfg, &s_tcb_stats, &s_handle_stats);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* Medium Priority: Terminal Visualizer Task */
    task_cfg.name = "Visualizer";
    task_cfg.entry_func = gaussian_task_visualizer_entry;
    task_cfg.param = NULL;
    task_cfg.priority = GAUSSIAN_PRIO_VISUALIZER;
    task_cfg.stack_buffer = s_stack_vis;
    task_cfg.stack_size = sizeof(s_stack_vis);
    status = sertos_task_create_static(&task_cfg, &s_tcb_vis, &s_handle_vis);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* Lowest Priority: Input Monitor Task */
    task_cfg.name = "Input";
    task_cfg.entry_func = gaussian_task_input_entry;
    task_cfg.param = NULL;
    task_cfg.priority = GAUSSIAN_PRIO_INPUT;
    task_cfg.stack_buffer = s_stack_input;
    task_cfg.stack_size = sizeof(s_stack_input);
    status = sertos_task_create_static(&task_cfg, &s_tcb_input, &s_handle_input);
    if (status != SERTOS_STATUS_OK) {
        return status;
    }

    /* 6. Start the 50 Hz Software Timer */
    status = sertos_timer_start(s_timer_handle);
    return status;
}
