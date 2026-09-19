/**
 * @file gaussian_tasks.h
 * @brief Task entries, RTOS primitive declarations, and synchronization hierarchy.
 *
 * Implements the 4-task execution hierarchy (Ingestion, Stats, Visualizer, Input)
 * and the 50 Hz autonomous sensor acquisition timer.
 */

#ifndef GAUSSIAN_TASKS_H
#define GAUSSIAN_TASKS_H

#include "sertos_task.h"
#include "sertos_queue.h"
#include "sertos_mutex.h"
#include "sertos_sem.h"
#include "sertos_timer.h"
#include "gaussian_state.h"

/**
 * @brief Task priority levels conforming to the hierarchical specification.
 */
#define GAUSSIAN_PRIO_INPUT       (1U) /**< Lowest application priority (above Idle). */
#define GAUSSIAN_PRIO_VISUALIZER  (2U) /**< Medium priority for UI updates. */
#define GAUSSIAN_PRIO_STATS       (3U) /**< High priority for mathematical moment updates. */
#define GAUSSIAN_PRIO_INGESTION   (4U) /**< Highest priority for incoming sample routing. */

/**
 * @brief Task stack buffer sizes in bytes (8-byte aligned).
 */
#define GAUSSIAN_STACK_SIZE_INGESTION   (2048U)
#define GAUSSIAN_STACK_SIZE_STATS       (2048U)
#define GAUSSIAN_STACK_SIZE_VISUALIZER  (4096U)
#define GAUSSIAN_STACK_SIZE_INPUT       (1024U)

/**
 * @brief Autonomous hardware acquisition timer interval (50 Hz = 20 ms / 20 ticks).
 */
#define GAUSSIAN_TIMER_PERIOD_TICKS     (20U)

/**
 * @brief Visualizer frame interval (12.5 FPS = 80 ms / 80 ticks).
 */
#define GAUSSIAN_VIS_DELAY_TICKS        (80U)

/**
 * @brief Input polling interval (50 ms / 50 ticks).
 */
#define GAUSSIAN_INPUT_DELAY_TICKS      (50U)

/**
 * @brief Initializes all static RTOS primitives (queue, mutex, semaphore, timer) and tasks.
 *
 * @return SERTOS_STATUS_OK on success, or error status code.
 */
SertosStatus gaussian_tasks_init(void);

/**
 * @brief Ingestion Engine Task entry function (Highest Priority).
 *
 * Blocks on incoming sample queue, maps values into 21 bins under mutex,
 * buffers into 50-sample batch, and signals the batch semaphore.
 *
 * @param param Unused task context argument.
 */
void gaussian_task_ingestion_entry(void* param);

/**
 * @brief Statistical Engine Task entry function (High Priority).
 *
 * Blocks on batch semaphore, drains 50 raw samples from batch buffer,
 * and updates Welford running moments under mutex.
 *
 * @param param Unused task context argument.
 */
void gaussian_task_stats_entry(void* param);

/**
 * @brief Terminal Visualizer Task entry function (Medium Priority).
 *
 * Runs periodically at 12.5 FPS, captures mutex-protected snapshot,
 * and renders flicker-free ANSI ASCII bell curve.
 *
 * @param param Unused task context argument.
 */
void gaussian_task_visualizer_entry(void* param);

/**
 * @brief Input Monitor Task entry function (Lowest Priority).
 *
 * Periodically polls non-blocking console input to handle user commands
 * (pause/resume, reset, quit).
 *
 * @param param Unused task context argument.
 */
void gaussian_task_input_entry(void* param);

/**
 * @brief Periodic 50 Hz software timer callback (sensor/ADC acquisition proxy).
 *
 * Generates Irwin-Hall normal random sample and performs non-blocking post to queue.
 *
 * @param handle Timer handle.
 * @param param  User parameter.
 */
void gaussian_timer_acquisition_callback(SertosTimerHandle handle, void* param);

#endif /* GAUSSIAN_TASKS_H */
