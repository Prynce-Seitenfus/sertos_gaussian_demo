/**
 * @file terminal_ui.c
 * @brief Implementation of the flicker-free ANSI single-column terminal visualizer.
 *
 * Renders the full 21-bin Gaussian distribution bell curve in a continuous
 * vertical column with 45-character peak normalization. Strictly formatted
 * to 24 lines and 70 columns to prevent scrolling on standard 80x24 terminals.
 * Also provides an interactive single-line log stream mode.
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
 * @brief Tracks previous stream mode for clean screen clearing on transition.
 */
static bool s_prev_stream_mode = false;
static bool s_first_frame = true;

/**
 * @brief ANSI escape sequence constants.
 */
#define ANSI_CURSOR_UP_24   "\033[24A\r"
#define ANSI_CLEAR_SCREEN   "\033[2J"
#define ANSI_CLEAR_DOWN     "\033[J"
#define ANSI_RESET          "\033[0m"
#define ANSI_BOLD           "\033[1m"
#define ANSI_COLOR_CYAN     "\033[36m"
#define ANSI_COLOR_GREEN    "\033[32m"
#define ANSI_COLOR_YELLOW   "\033[33m"
#define ANSI_COLOR_RED      "\033[31m"
#define ANSI_COLOR_WHITE    "\033[37m"
#define ANSI_COLOR_GRAY     "\033[90m"
#define ANSI_SHOW_CURSOR    "\033[?25h"
#define ANSI_HIDE_CURSOR    "\033[?25l"

void terminal_ui_init(void)
{
    bsp_console_init();
    s_prev_stream_mode = false;
    s_first_frame = true;
    bsp_console_puts(ANSI_HIDE_CURSOR);
}

void terminal_ui_cleanup(void)
{
    bsp_console_puts(ANSI_RESET ANSI_SHOW_CURSOR "\r\n\r\n");
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

    /* Stream Mode: Linear log output without ANSI cursor positioning */
    if (state->stream_mode) {
        s_prev_stream_mode = true;
        (void)snprintf(s_render_buf, sizeof(s_render_buf),
            "[SERTOS] N=%-6u | mu=%+7.4f | s=%6.4f | s2=%6.4f | Drop=%-2u | %s\n",
            (unsigned int)state->total_samples,
            state->stats.mean,
            state->stats.std_dev,
            state->stats.variance,
            (unsigned int)state->dropped_samples,
            state->is_paused ? "PAUSED" : "RUNNING");
        bsp_console_puts(s_render_buf);
        return;
    }

    /* Transitioning back from stream mode to dashboard */
    if (s_prev_stream_mode) {
        s_first_frame = true;
        s_prev_stream_mode = false;
    }

    /* Move cursor up to overwrite previous dashboard frame without clearing banner above */
    if (!s_first_frame) {
        offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
            ANSI_CURSOR_UP_24);
    } else {
        s_first_frame = false;
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

    /* Line 1: Compact Telemetry Header & Moments (width ~71 chars, strictly < 80) */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD ANSI_COLOR_CYAN "SertOS" ANSI_RESET
        " | %s%-7s" ANSI_RESET
        " | " ANSI_BOLD "N:" ANSI_RESET " " ANSI_COLOR_WHITE "%-6u" ANSI_RESET
        " | " ANSI_BOLD "mu:" ANSI_RESET " " ANSI_COLOR_GREEN "%+6.3f" ANSI_RESET
        " | " ANSI_BOLD "s:" ANSI_RESET " " ANSI_COLOR_GREEN "%5.3f" ANSI_RESET
        " | " ANSI_BOLD "Var:" ANSI_RESET " " ANSI_COLOR_GREEN "%5.3f" ANSI_RESET
        " | " ANSI_BOLD "Drop:" ANSI_RESET " " ANSI_COLOR_RED "%-2u" ANSI_RESET "\n",
        status_color, status_str,
        (unsigned int)state->total_samples,
        state->stats.mean,
        state->stats.std_dev,
        state->stats.variance,
        (unsigned int)state->dropped_samples);

    /* Line 2: Table Header (width 66 chars) */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD "Bin Range         Count  Normalized Distribution [45-character scale]" ANSI_RESET "\n");

    /* Lines 3 to 23: Exactly 21 Continuous Gaussian Bins in 1 Column (width 70 chars) */
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
            "%2u [%+5.2f,%+5.2f] %5u |%s",
            (unsigned int)i, low, high, (unsigned int)state->bins[i], color);

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

    /* Line 24: Interactive Controls & Instructions (width 72 chars, total lines = 24) */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD "[CONTROLS]" ANSI_RESET
        "  [P] Pause/Resume    [R] Reset    [M] Stream Mode    [Q] Exit Demo\n"
        ANSI_RESET);

    bsp_console_puts(s_render_buf);
}
