/**
 * @file terminal_ui.h
 * @brief Flicker-free ANSI terminal dashboard renderer.
 *
 * Renders an interactive, colored ASCII dashboard with dynamic 45-character
 * normalization across 21 histogram bins and real-time statistical metrics.
 */

#ifndef TERMINAL_UI_H
#define TERMINAL_UI_H

#include "gaussian_state.h"

/**
 * @brief Initializes terminal display state and clears screen once at launch.
 */
void terminal_ui_init(void);

/**
 * @brief Renders the complete statistical dashboard using ANSI cursor-home positioning.
 *
 * @param[in] state Pointer to a consistent snapshot of the GaussianState record.
 */
void terminal_ui_render(const GaussianState* state);

/**
 * @brief Restores terminal display attributes and cursor upon shutdown.
 */
void terminal_ui_cleanup(void);

#endif /* TERMINAL_UI_H */
