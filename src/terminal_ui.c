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
#include "sertos_stats.h"
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
 * @brief Tracks previous stats-view mode to force a clean redraw on transition.
 */
static bool s_prev_show_stats = false;

/**
 * @brief ANSI escape sequence constants.
 */
#define ANSI_CURSOR_UP_24   "\033[24A\r"
#define ANSI_CLEAR_SCREEN   "\033[2J"
#define ANSI_CLEAR_DOWN     "\033[J"
#define ANSI_CLEAR_EOL      "\033[K"
#define ANSI_REDRAW         ANSI_CURSOR_UP_24 ANSI_CLEAR_DOWN
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
    s_prev_show_stats = false;
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

/**
 * @brief Maps a task lifecycle state to a fixed-width 4-character label.
 *
 * @param st Task state value.
 * @return Pointer to a static 4-character state label string.
 */
static const char* task_state_str(SertosTaskState st)
{
    const char* result;

    switch (st) {
        case SERTOS_TASK_STATE_RUNNING:
            result = "RUN ";
            break;
        case SERTOS_TASK_STATE_READY:
            result = "RDY ";
            break;
        case SERTOS_TASK_STATE_BLOCKED:
            result = "BLK ";
            break;
        case SERTOS_TASK_STATE_SUSPENDED:
            result = "SUSP";
            break;
        default:
            result = "TERM";
            break;
    }

    return result;
}

/**
 * @brief Appends the 24-line live kernel task-statistics view into the render buffer.
 *
 * @param[in,out] offset_io Running write offset into s_render_buf, advanced in place.
 */
static void append_stats_view(size_t* offset_io)
{
    SertosTaskStats tasks[SERTOS_CONFIG_STATS_MAX_TASKS];
    SertosSystemStats sys;
    size_t count;
    size_t i;
    size_t blanks;
    size_t offset = *offset_io;
    uint32_t cpu_x100;

    (void)memset(&sys, 0, sizeof(sys));
    (void)sertos_stats_get_system(&sys);
    count = sertos_stats_get_tasks(tasks, SERTOS_CONFIG_STATS_MAX_TASKS);
    cpu_x100 = (sys.idle_percent_x100 <= 10000U) ? (10000U - sys.idle_percent_x100) : 0U;

    /* Line 1: System telemetry header (kept well under 80 cols to avoid wrap) */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD ANSI_COLOR_CYAN "SertOS Live Stats" ANSI_RESET
        " | " ANSI_BOLD "CPU:" ANSI_RESET " " ANSI_COLOR_GREEN "%3u.%02u%%" ANSI_RESET
        " | " ANSI_BOLD "Idle:" ANSI_RESET " " ANSI_COLOR_YELLOW "%3u.%02u%%" ANSI_RESET
        " | " ANSI_BOLD "Switches:" ANSI_RESET " " ANSI_COLOR_WHITE "%u" ANSI_RESET ANSI_CLEAR_EOL "\n",
        (unsigned int)(cpu_x100 / 100U), (unsigned int)(cpu_x100 % 100U),
        (unsigned int)(sys.idle_percent_x100 / 100U), (unsigned int)(sys.idle_percent_x100 % 100U),
        (unsigned int)sys.total_switches);

    /* Line 2: Table header */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD "Task             Pri  State   CPU%%       Switches   StackFree" ANSI_RESET ANSI_CLEAR_EOL "\n");

    /* Lines 3..(2+count): one row per live task */
    for (i = 0U; i < count; i++) {
        offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
            "%-16s %3u  %-4s   %4u.%02u%%  %9u  %8lu" ANSI_CLEAR_EOL "\n",
            (tasks[i].name != NULL) ? tasks[i].name : "?",
            (unsigned int)tasks[i].priority,
            task_state_str(tasks[i].state),
            (unsigned int)(tasks[i].cpu_percent_x100 / 100U),
            (unsigned int)(tasks[i].cpu_percent_x100 % 100U),
            (unsigned int)tasks[i].switch_in_count,
            (unsigned long)tasks[i].stack_high_water);
    }

    /* Pad with blank lines so the controls row always lands on line 24 */
    blanks = (count < 21U) ? (21U - count) : 0U;
    for (i = 0U; i < blanks; i++) {
        offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset, ANSI_CLEAR_EOL "\n");
    }

    /* Line 24: Interactive controls (width 65 chars, strictly < 80 to avoid wrap) */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD "[CONTROLS]" ANSI_RESET
        "  [P] Pause  [R] Reset  [M] Stream  [S] Curve  [Q] Exit" ANSI_CLEAR_EOL "\n"
        ANSI_RESET);

    *offset_io = offset;
}

/**
 * @brief Appends a single normalized histogram bin row to the render buffer.
 *
 * @param[in]     state     Snapshot of the GaussianState record.
 * @param[in]     bin       Bin index in [0, GAUSSIAN_NUM_BINS).
 * @param[in]     max_count Peak bin count used for horizontal normalization.
 * @param[in,out] offset_io Running write offset into s_render_buf.
 */
static void append_bin_row(const GaussianState* state, uint32_t bin, uint32_t max_count, size_t* offset_io)
{
    double low = GAUSSIAN_RANGE_MIN + ((double)bin * GAUSSIAN_BIN_WIDTH);
    double high = low + GAUSSIAN_BIN_WIDTH;
    uint32_t bar_len = 0U;
    uint32_t j;
    size_t offset = *offset_io;
    const char* color = get_bin_color(bin);

    if (max_count > 0U) {
        bar_len = (state->bins[bin] * GAUSSIAN_DISPLAY_MAX_WIDTH) / max_count;
        if ((bar_len == 0U) && (state->bins[bin] > 0U)) {
            bar_len = 1U;
        }
    }

    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        "%2u [%+5.2f,%+5.2f] %5u |%s",
        (unsigned int)bin, low, high, (unsigned int)state->bins[bin], color);

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

    *offset_io = offset;
}

/**
 * @brief Appends the 24-line Gaussian bell-curve dashboard into the render buffer.
 *
 * @param[in]     state     Snapshot of the GaussianState record.
 * @param[in,out] offset_io Running write offset into s_render_buf.
 */
static void append_dashboard_view(const GaussianState* state, size_t* offset_io)
{
    uint32_t max_count = 0U;
    uint32_t i;
    size_t offset = *offset_io;
    const char* status_str;
    const char* status_color;

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
        append_bin_row(state, i, max_count, &offset);
    }

    /* Line 24: Interactive Controls & Instructions (width 72 chars, total lines = 24) */
    offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
        ANSI_BOLD "[CONTROLS]" ANSI_RESET
        "  [P] Pause  [R] Reset  [M] Stream  [S] Stats  [Q] Exit\n"
        ANSI_RESET);

    *offset_io = offset;
}

/**
 * @brief Emits the single-line stream-mode telemetry record.
 *
 * @param[in] state Snapshot of the GaussianState record.
 */
static void render_stream_line(const GaussianState* state)
{
    (void)snprintf(s_render_buf, sizeof(s_render_buf),
        "[SERTOS] N=%-6u | mu=%+7.4f | s=%6.4f | s2=%6.4f | Drop=%-2u | %s\n",
        (unsigned int)state->total_samples,
        state->stats.mean,
        state->stats.std_dev,
        state->stats.variance,
        (unsigned int)state->dropped_samples,
        state->is_paused ? "PAUSED" : "RUNNING");
    bsp_console_puts(s_render_buf);
}

void terminal_ui_render(const GaussianState* state)
{
    size_t offset = 0U;
    bool view_changed;

    if (state == NULL) {
        return;
    }

    /* Stream Mode: Linear log output without ANSI cursor positioning */
    if (state->stream_mode) {
        s_prev_stream_mode = true;
        render_stream_line(state);
        return;
    }

    /* Transitioning back from stream mode to dashboard */
    if (s_prev_stream_mode) {
        s_first_frame = true;
        s_prev_stream_mode = false;
    }

    /* On a view-type change, clear residue below before repainting the 24-line block */
    view_changed = (state->show_stats != s_prev_show_stats);
    if (!s_first_frame) {
        offset += (size_t)snprintf(s_render_buf + offset, sizeof(s_render_buf) - offset,
            view_changed ? ANSI_REDRAW : ANSI_CURSOR_UP_24);
    } else {
        s_first_frame = false;
    }

    if (state->show_stats) {
        append_stats_view(&offset);
    } else {
        append_dashboard_view(state, &offset);
    }
    s_prev_show_stats = state->show_stats;

    bsp_console_puts(s_render_buf);
}
