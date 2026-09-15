/**
 * @file gaussian_state.c
 * @brief Implementation of state initialization and reset operations.
 */

#include "gaussian_state.h"
#include <string.h>

void gaussian_state_init(GaussianState* state)
{
    if (state != NULL) {
        (void)memset(state, 0, sizeof(GaussianState));
        welford_init(&state->stats);
        state->is_paused = false;
        state->should_terminate = false;
    }
}

void gaussian_state_reset(GaussianState* state)
{
    if (state != NULL) {
        (void)memset(state->bins, 0, sizeof(state->bins));
        state->total_samples = 0U;
        state->dropped_samples = 0U;
        state->batch_count = 0U;
        welford_reset(&state->stats);
    }
}
