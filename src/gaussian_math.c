/**
 * @file gaussian_math.c
 * @brief Mathematical routines for Gaussian distribution generation and statistics.
 *
 * Provides deterministic XorShift32 PRNG, Irwin-Hall 12-sample normal deviates,
 * 21-bin equidistant discretization, and Welford's online variance algorithm.
 */

#include "gaussian_math.h"
#include <math.h>
#include <string.h>

/**
 * @brief Default non-zero seed used when caller provides 0.
 */
#define GAUSSIAN_DEFAULT_SEED      (0x854329A5U)

/**
 * @brief Divisor used to normalize 32-bit integers to [0.0, 1.0) double values (2^32).
 */
#define GAUSSIAN_NORMALIZE_FACTOR  (4294967296.0)

void gaussian_prng_init(GaussianPrng* prng, uint32_t seed)
{
    if (prng != NULL) {
        prng->state = (seed != 0U) ? seed : GAUSSIAN_DEFAULT_SEED;
    }
}

double gaussian_prng_next_uniform(GaussianPrng* prng)
{
    uint32_t x;

    if (prng == NULL) {
        return 0.0;
    }

    x = prng->state;
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    prng->state = x;

    return (double)x / GAUSSIAN_NORMALIZE_FACTOR;
}

double gaussian_math_sample_irwin_hall(GaussianPrng* prng)
{
    double sum = 0.0;
    uint32_t i;

    for (i = 0U; i < GAUSSIAN_IRWIN_HALL_TERMS; i++) {
        sum += gaussian_prng_next_uniform(prng);
    }

    return sum - GAUSSIAN_IRWIN_HALL_OFFSET;
}

uint32_t gaussian_math_value_to_bin(double value)
{
    int32_t bin;

    if (value < GAUSSIAN_RANGE_MIN) {
        return 0U;
    }
    if (value >= GAUSSIAN_RANGE_MAX) {
        return GAUSSIAN_NUM_BINS - 1U;
    }

    bin = (int32_t)floor((value - GAUSSIAN_RANGE_MIN) / GAUSSIAN_BIN_WIDTH);
    if (bin < 0) {
        return 0U;
    }
    if ((uint32_t)bin >= GAUSSIAN_NUM_BINS) {
        return GAUSSIAN_NUM_BINS - 1U;
    }

    return (uint32_t)bin;
}

double gaussian_math_bin_to_center(uint32_t bin_index)
{
    if (bin_index >= GAUSSIAN_NUM_BINS) {
        bin_index = GAUSSIAN_NUM_BINS - 1U;
    }

    return GAUSSIAN_RANGE_MIN + (((double)bin_index + 0.5) * GAUSSIAN_BIN_WIDTH);
}

void welford_init(WelfordState* ws)
{
    if (ws != NULL) {
        (void)memset(ws, 0, sizeof(WelfordState));
    }
}

void welford_update(WelfordState* ws, double value)
{
    double delta;
    double delta2;

    if (ws == NULL) {
        return;
    }

    ws->count++;
    delta = value - ws->mean;
    ws->mean += (delta / (double)ws->count);
    delta2 = value - ws->mean;
    ws->m2 += (delta * delta2);

    if (ws->count > 1U) {
        ws->variance = ws->m2 / (double)(ws->count - 1U);
        ws->std_dev = sqrt(ws->variance);
    } else {
        ws->variance = 0.0;
        ws->std_dev = 0.0;
    }
}

void welford_reset(WelfordState* ws)
{
    welford_init(ws);
}
