/**
 * @file gaussian_math.h
 * @brief Deterministic pseudo-random number generator and statistical calculations.
 *
 * Implements XorShift32 PRNG, Irwin-Hall 12-sample standard normal distribution
 * generation, 21-bin equidistant discretization, and Welford's online variance algorithm.
 * Strictly ISO C99 and MISRA C:2012 compliant with zero dynamic memory allocation.
 */

#ifndef GAUSSIAN_MATH_H
#define GAUSSIAN_MATH_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Number of equidistant histogram bins spanning [-3.0, +3.0].
 */
#define GAUSSIAN_NUM_BINS          (21U)

/**
 * @brief Minimum statistical boundary for bin discretization (-3.0 sigma).
 */
#define GAUSSIAN_RANGE_MIN         (-3.0)

/**
 * @brief Maximum statistical boundary for bin discretization (+3.0 sigma).
 */
#define GAUSSIAN_RANGE_MAX         (3.0)

/**
 * @brief Total span of the discretized interval (6.0 sigma).
 */
#define GAUSSIAN_RANGE_SPAN        (6.0)

/**
 * @brief Width of each histogram bin (approximately 0.2857142857142857).
 */
#define GAUSSIAN_BIN_WIDTH         (GAUSSIAN_RANGE_SPAN / (double)GAUSSIAN_NUM_BINS)

/**
 * @brief Number of uniform deviates summed in the Irwin-Hall generator.
 */
#define GAUSSIAN_IRWIN_HALL_TERMS  (12U)

/**
 * @brief Mean offset subtracted in the 12-sample Irwin-Hall generator.
 */
#define GAUSSIAN_IRWIN_HALL_OFFSET (6.0)

/**
 * @brief PRNG state container for deterministic XorShift32 generation.
 */
typedef struct GaussianPrng {
    uint32_t state; /**< Internal 32-bit PRNG shift state (must be non-zero). */
} GaussianPrng;

/**
 * @brief Online running statistics accumulator using Welford's algorithm.
 */
typedef struct WelfordState {
    uint32_t count;   /**< Total number of accumulated samples. */
    double mean;      /**< Running arithmetic mean. */
    double m2;        /**< Running sum of squared differences from the mean. */
    double variance;  /**< Sample variance (m2 / (count - 1)). */
    double std_dev;   /**< Sample standard deviation (sqrt(variance)). */
} WelfordState;

/**
 * @brief Initializes the deterministic PRNG state with a non-zero seed.
 *
 * @param[out] prng Pointer to GaussianPrng instance.
 * @param[in]  seed Seed value. If seed is 0, defaults to a non-zero fallback seed.
 */
void gaussian_prng_init(GaussianPrng* prng, uint32_t seed);

/**
 * @brief Generates a pseudo-random uniform deviate in the interval [0.0, 1.0).
 *
 * @param[in,out] prng Pointer to GaussianPrng instance.
 * @return Uniformly distributed double precision value.
 */
double gaussian_prng_next_uniform(GaussianPrng* prng);

/**
 * @brief Generates a standard normal random sample via the Irwin-Hall distribution.
 *
 * Computes the sum of 12 independent uniform deviates minus 6.0, yielding a
 * theoretical distribution with mean 0.0 and variance 1.0 in constant time O(1).
 *
 * @param[in,out] prng Pointer to GaussianPrng instance.
 * @return Standard normal pseudo-random sample.
 */
double gaussian_math_sample_irwin_hall(GaussianPrng* prng);

/**
 * @brief Maps a numerical sample value into one of 21 histogram bin indices.
 *
 * Values falling below GAUSSIAN_RANGE_MIN are clamped to bin 0.
 * Values falling at or above GAUSSIAN_RANGE_MAX are clamped to bin 20.
 *
 * @param[in] value Numerical sample value.
 * @return Bin index in the range [0, 20].
 */
uint32_t gaussian_math_value_to_bin(double value);

/**
 * @brief Retrieves the center value (midpoint) of a specific histogram bin.
 *
 * @param[in] bin_index Bin index in the range [0, 20].
 * @return Midpoint value of the bin.
 */
double gaussian_math_bin_to_center(uint32_t bin_index);

/**
 * @brief Initializes or resets a WelfordState structure to zero.
 *
 * @param[out] ws Pointer to WelfordState instance.
 */
void welford_init(WelfordState* ws);

/**
 * @brief Updates running moments with a new sample value using Welford's algorithm.
 *
 * Numerically stable single-pass update preventing catastrophic cancellation.
 *
 * @param[in,out] ws    Pointer to WelfordState instance.
 * @param[in]     value New sample value.
 */
void welford_update(WelfordState* ws, double value);

/**
 * @brief Resets accumulated statistics back to initial state.
 *
 * @param[out] ws Pointer to WelfordState instance.
 */
void welford_reset(WelfordState* ws);

#endif /* GAUSSIAN_MATH_H */
