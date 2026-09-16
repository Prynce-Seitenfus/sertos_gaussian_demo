/**
 * @file gaussian_state.h
 * @brief Global statistics and configuration state container.
 *
 * Defines the shared state records, synchronization parameters, and batch buffers
 * shared across the real-time demonstration tasks.
 */

#ifndef GAUSSIAN_STATE_H
#define GAUSSIAN_STATE_H

#include <stdint.h>
#include <stdbool.h>
#include "gaussian_math.h"

/**
 * @brief Number of samples accumulated in a single batch before signaling Statistical Engine.
 */
#define GAUSSIAN_BATCH_SIZE         (50U)

/**
 * @brief Maximum capacity of the incoming numerical sample message queue.
 */
#define GAUSSIAN_QUEUE_DEPTH        (32U)

/**
 * @brief Maximum horizontal column width allocated for the bell curve ASCII bars.
 */
#define GAUSSIAN_DISPLAY_MAX_WIDTH  (45U)

/**
 * @brief Shared runtime statistics record protected by the application mutex.
 */
typedef struct GaussianState {
    uint32_t bins[GAUSSIAN_NUM_BINS]; /**< Histogram bin counters covering [-3.0, +3.0]. */
    uint32_t total_samples;           /**< Total count of ingested and binned samples. */
    uint32_t dropped_samples;         /**< Samples dropped due to queue saturation. */
    uint32_t batch_count;             /**< Completed 50-sample batches processed. */
    WelfordState stats;               /**< Running arithmetic mean, variance, and std dev. */
    bool is_paused;                   /**< True if sample generation is paused by user. */
    bool should_terminate;            /**< True if application shutdown was requested. */
    bool stream_mode;                 /**< True for linear log stream mode instead of ANSI dashboard. */
} GaussianState;

/**
 * @brief Initializes the GaussianState structure fields to zero/default values.
 *
 * @param[out] state Pointer to GaussianState instance.
 */
void gaussian_state_init(GaussianState* state);

/**
 * @brief Resets all bins, counts, and statistical moments while preserving control flags.
 *
 * @param[in,out] state Pointer to GaussianState instance.
 */
void gaussian_state_reset(GaussianState* state);

#endif /* GAUSSIAN_STATE_H */
