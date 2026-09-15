/**
 * @file terminal_ui.c
 * @brief Implementation of the flicker-free ANSI terminal visualizer.
 *
 * Emits cursor-home sequences (\033[H), normalizes peak bin counts to 45 columns,
 * and renders a colored horizontal bell curve with numerical telemetry.
 */

#include "terminal_ui.h"
#include "bsp_console.h"
#include <stdio.h>
#include <string.h>
#include <math.h>

/**
 * @brief Static scratch buffer for formatted output (zero dynamic heap).
 */
static char s_render_buf[4096];

/**
 * @brief ANSI escape sequence constants.
 */
#define ANSI_CURSOR_HOME    "\033[H"
#define ANSI_CLEAR_SCREEN   "\033[2J"
#define ANSI_RESET          "\033[0m"
#define ANSI_BOLD           "\033[1m"
#define ANSI_COLOR_CYAN     "\033[36m"
#define ANSI_COLOR_GREEN    "\033[32m"
#define ANSI_COLOR_YELLOW   "\033[33m"
#define ANSI_COLOR_RED      "\033[31m"
#define ANSI_COLOR_MAGENTA  "\033[35m"
#define ANSI_COLOR_WHITE    "\033[37m"
#define ANSI_COLOR_GRAY     "\033[90m"

void terminal_ui_init(void)
{
    bsp_console_init();
    /* Clear screen once upon startup */
    bsp_console_puts(ANSI_CLEAR_SCREEN ANSI_CURSOR_HOME);
}

void terminal_ui_cleanup(void)
{
    bsp_console_cleanup();
}

/**
 * @brief Selects ANSI color formatting based on bin distance from the mean.
 *
 * @param bin_index Index in [0, 20].
 * @return ANSI color escape sequence string.
 */
static const char* get_bin_color(uint32_t bin_index)
{
    /* Central peak: |z| < 1.0 sigma (bins 8 through 12) */
    if ((bin_index >= 8U) && (bin_index <= 12U)) {
        return ANSI_BOLD ANSI_COLOR_CYAN;
    }

    /* Intermediate: 1.0 <= |z| < 2.0 sigma (bins 4..7 and 13..16) */
    if ((bin_index >= 4U) && (bin_index <= 16U)) {
        return ANSI_BOLD ANSI_COLOR_GREEN;
    }

    /* Outer tails: |z| >= 2.0 sigma (bins 0..3 and 17..20) */
    return ANSI_BOLD ANSI_COLOR_YELLOW;
}

void terminal_ui_render(const GaussianState* state)
{
    uint32_t max_count = 0U;
    uint32_t i;
    uint32_t j;
    size_t offset = 0U;
    const char* status_str;
    const char* status_color;

    if (state == NULL) {
        return;
    }

    /* Identify peak bin count for dynamic normalization */
    for (i = 0U; i < GAUSSIAN_NUM_BINS; i++) {
        if (state->bins[i] > max_count) {
            max_count = state->bins[i];
        }
    }

    if (state->is_paused) {
        status_str = "PAUSED";
        status_color = ANSI_BOLD ANSI_COLOR_YELLOW;
    } else {
        status_str = "RUNNING";
        status_color = ANSI_BOLD ANSI_COLOR_GREEN;
    }

    /* Emit cursor home to begin overwrite */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_CURSOR_HOME
        ANSI_BOLD ANSI_COLOR_CYAN
        "========================================================================================\n"
        "           SertOS Preemptive RTOS — Real-Time Gaussian Distribution Showcase            \n"
        "========================================================================================\n"
        ANSI_RESET);

    /* Telemetry Header */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD "Status: " ANSI_RESET "%s%-8s" ANSI_RESET
        ANSI_BOLD " | Samples: " ANSI_COLOR_WHITE "%-7u" ANSI_RESET
        ANSI_BOLD " | Batches: " ANSI_COLOR_WHITE "%-5u" ANSI_RESET
        ANSI_BOLD " | Dropped: " ANSI_COLOR_RED "%-4u" ANSI_RESET
        ANSI_BOLD " | Rate: " ANSI_COLOR_WHITE "50 Hz (20ms)\n" ANSI_RESET,
        status_color, status_str,
        state->total_samples,
        state->batch_count,
        state->dropped_samples);

    /* Statistical Moments */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD "Mean (mu):   " ANSI_COLOR_GREEN "%+7.4f" ANSI_RESET " (Target:  0.00 +/- 0.05)"
        ANSI_BOLD " | Variance (s2): " ANSI_COLOR_GREEN "%6.4f" ANSI_RESET "\n"
        ANSI_BOLD "StdDev (s):  " ANSI_COLOR_GREEN "%7.4f" ANSI_RESET " (Target:  1.00 +/- 0.05)"
        ANSI_BOLD " | Discretization: 21 equidistant bins\n" ANSI_RESET
        ANSI_COLOR_GRAY
        "----------------------------------------------------------------------------------------\n"
        ANSI_BOLD
        "Bin  Range [Sigma]   Count  Normalized Distribution [45-character peak scale]\n"
        ANSI_COLOR_GRAY
        "----------------------------------------------------------------------------------------\n"
        ANSI_RESET,
        state->stats.mean,
        state->stats.variance,
        state->stats.std_dev);

    /* 21 Histogram Bins */
    for (i = 0U; i < GAUSSIAN_NUM_BINS; i++) {
        double low = GAUSSIAN_RANGE_MIN + ((double)i * GAUSSIAN_BIN_WIDTH);
        double high = low + GAUSSIAN_BIN_WIDTH;
        uint32_t bar_len = 0U;
        const char* color = get_bin_color(i);

        if (max_count > 0U) {
            bar_len = (state->bins[i] * GAUSSIAN_DISPLAY_MAX_WIDTH) / max_count;
            if ((bar_len == 0U) && (state->bins[i] > 0U)) {
                bar_len = 1U;
            }
        }

        offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
            "%2u  [%+5.2f, %+5.2f]  %5u  |%s",
            i, low, high, state->bins[i], color);

        /* Render horizontal ASCII bar glyphs */
        for (j = 0U; j < bar_len; j++) {
            if (offset < (sizeof(s_render_buf) - 2U)) {
                s_render_buf[offset++] = '#';
            }
        }

        /* Pad remaining width */
        for (; j < GAUSSIAN_DISPLAY_MAX_WIDTH; j++) {
            if (offset < (sizeof(s_render_buf) - 2U)) {
                s_render_buf[offset++] = ' ';
            }
        }

        s_render_buf[offset] = '\0';
        offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
            ANSI_RESET "|\n");
    }

    /* Footer & Interactive Controls */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_COLOR_GRAY
        "----------------------------------------------------------------------------------------\n"
        ANSI_RESET
        ANSI_BOLD "[CONTROLS]" ANSI_RESET
        "  [P] Pause/Resume Generation   [R] Reset Statistics   [Q] Graceful Exit\n"
        ANSI_BOLD ANSI_COLOR_CYAN
        "========================================================================================\n"
        ANSI_RESET);

    bsp_console_puts(s_render_buf);
}
