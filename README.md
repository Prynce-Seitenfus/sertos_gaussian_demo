# SertOS Real-Time Gaussian Distribution Demonstration (`sertos_gaussian_demo`)

A standalone, real-time interactive showcase of preemptive multitasking and concurrent synchronization primitives built on **SertOS** with **zero dynamic memory allocation** (freestanding ISO C99 / MISRA C:2012 Rule 21.3).

---

## 1. Architectural Highlights

- **Multi-Port Portability**: Decoupled from the host operating system. The application core communicates exclusively through standard SertOS public APIs (`sertos_task.h`, `sertos_queue.h`, `sertos_timer.h`, `sertos_mutex.h`, `sertos_sem.h`).
  - **Windows Host (`bsp_console_windows.c`)**: ANSI Virtual Terminal Processing + non-blocking `_kbhit()` / `_getch()`.
  - **POSIX Host (`bsp_console_posix.c`)**: ANSI terminal + `termios` non-canonical input.
  - **Bare-Metal MCU (`bsp_console_uart_stub.c`)**: Direct UART TX/RX mapping for STM32H5, ARM Cortex-M, and RISC-V.
- **Zero Dynamic Memory Allocation**: Every task control block, execution stack, ring buffer storage, timer descriptor, and synchronization object is allocated statically at compile time in `.bss` / `.data` (RAM budget < 12 KB).
- **Preemptive Concurrency Pipeline**:
  1. **50 Hz Software Timer (20 ms interval)**: Simulates an autonomous hardware acquisition interrupt, producing standard normal samples ($\mu = 0, \sigma = 1$) via the 12-sample Irwin-Hall distribution and non-blockingly posting to the queue.
  2. **32-Element Static Message Queue**: Decouples high-frequency data generation from bin processing.
  3. **Ingestion Engine (Highest Priority)**: Dequeues samples, maps them into 21 histogram bins covering $[-3.0\sigma, +3.0\sigma]$ under mutex, and signals the batch semaphore every 50 samples.
  4. **Statistical Engine (High Priority)**: Blocks on the batch semaphore, draining 50 raw samples into Welford's online variance algorithm to compute continuous mean, variance, and standard deviation without catastrophic cancellation.
  5. **Terminal Visualizer (Medium Priority)**: Runs at 12.5 FPS (80 ms), acquires a mutex snapshot, normalizes peak bin counts to 45 columns, and renders a horizontal bell curve using ANSI cursor-home (`\033[H`) positioning.
  6. **Input Monitor (Lowest Priority)**: Polls non-blocking console input every 50 ms to handle pause/resume (`'P'`), reset (`'R'`), and graceful shutdown (`'Q'`).

---

## 2. Directory Structure

```
sertos_gaussian_demo/
├── CMakeLists.txt                         <- Strict C99 build configuration
├── README.md                              <- User guide and architecture documentation
├── inc/
│   ├── bsp_console.h                      <- Hardware/OS console abstraction
│   ├── gaussian_math.h                    <- XorShift32 PRNG, Irwin-Hall, Welford algorithm
│   ├── gaussian_state.h                   <- Shared statistics record and constants
│   ├── gaussian_tasks.h                   <- Task entries and RTOS configuration
│   └── terminal_ui.h                      <- Flicker-free ANSI 45-column dashboard
└── src/
    ├── main.c                             <- Application bootstrap & scheduler kickoff
    ├── gaussian_math.c                    <- Mathematical routines
    ├── gaussian_state.c                   <- State initialization and reset routines
    ├── gaussian_tasks.c                   <- Task implementations and static setups
    ├── terminal_ui.c                      <- ANSI color gradient rendering engine
    └── bsp/
        ├── bsp_console_windows.c          <- Windows console driver
        ├── bsp_console_posix.c            <- POSIX console driver
        └── bsp_console_uart_stub.c        <- Embedded MCU UART driver template
```

---

## 3. Compilation & Execution

The demonstration provides a unified `build.bat` script that compiles for the Windows host or any ARM Cortex bare-metal target:

### Quick Build (Unified Script)
```powershell
cd C:\github\sertos_gaussian_demo

# Build everything (Host executables + all 4 ARM Cortex binaries)
.\build.bat all

# Build Windows host executable (build\sertos_gaussian_demo.exe)
.\build.bat windows

# Build POSIX host library & binary
.\build.bat posix

# Build all 4 ARM Cortex binaries (build\sertos_gaussian_demo_m*.elf)
.\build.bat arm

# Build a single ARM Cortex target (m0, m3, m4, or m33)
.\build.bat m33
```

### Running the Demo (`run.bat`)
Use the unified [`run.bat`](file:///C:/github/sertos_gaussian_demo/run.bat) script to execute either on the Windows host simulator, POSIX host simulator (WSL / Linux), or bare-metal in QEMU:

```powershell
# Run Windows host demo (build\sertos_gaussian_demo.exe)
.\run.bat
.\run.bat windows

# Run POSIX host simulator (via WSL / Linux)
.\run.bat posix

# Run ARM Cortex targets in QEMU emulator
.\run.bat m33
.\run.bat m4
.\run.bat m3
.\run.bat m0

# Display help and supported targets
.\run.bat -h
```

Supported targets:
- **`windows`**: Native Windows Host (Win32 threads + Multimedia Timer) `[Default]`
- **`posix`**: POSIX Multitasking Simulation (Pthreads + WSL / Linux)
- **`m33` / `cortex-m33`**: ARM MPS2-AN505 (ARMv8-M Mainline)
- **`m4` / `cortex-m4`**: ARM MPS2-AN386 (ARMv7E-M)
- **`m3` / `cortex-m3`**: ARM MPS2-AN385 (ARMv7-M)
- **`m0` / `cortex-m0`**: ARM MPS2-AN385 (ARMv6-M)

### Interactive Controls
- **`[P]` or `[Space]`**: Pause or resume sample generation.
- **`[R]`**: Reset histogram bin counts and statistical moments to zero.
- **`[M]`**: Toggle between the compact stationary ANSI dashboard and the linear log stream mode (ideal for serial loggers / non-ANSI terminals).
- **`[Q]` or `[Esc]`**: Gracefully shut down the scheduler, restore terminal cursor, and exit.

> [!TIP]
> **QEMU Control**: When running in QEMU, press `[Q]` in the demo UI or `Ctrl+A` then `X` to exit.

---

## 5. Verification & Statistical Convergence

Run the centralized unit test suite in `test_bench/tests/test_gaussian_math.c`:
```powershell
gcc -Wall -Wextra -pedantic -std=c99 -I C:/github/sertos_gaussian_demo/inc C:/github/test_bench/tests/test_gaussian_math.c C:/github/sertos_gaussian_demo/src/gaussian_math.c -lm -o C:/github/test_bench/tests/test_gaussian_math.exe
C:\github\test_bench\tests\test_gaussian_math.exe
```

Expected output confirms convergence over $>2,000$ samples:
- **Empirical Mean**: $0.00 \pm 0.05$
- **Empirical Standard Deviation**: $1.00 \pm 0.05$

