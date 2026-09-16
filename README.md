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

## 3. Compilation & Execution (Windows Host / MinGW)

### Prerequisites
- GCC / MinGW-w64 (supporting C99)
- CMake 3.10+
- Pre-compiled SertOS library at `../sertos/lib/windows/libsertos_windows.a`

### Build Instructions (Automated Batch Script)
```powershell
cd C:\github\sertos_gaussian_demo
.\build_host.bat

# Optionally build and launch immediately:
.\build_host.bat --run
```

### Build Instructions (CMake Alternative)
```powershell
# 1. Build the SertOS Windows host library (if not already built)
cd C:\github\sertos
.\build_host.bat windows

# 2. Build the Gaussian Demonstration via CMake
cd C:\github\sertos_gaussian_demo
cmake -B build -G "MinGW Makefiles"
cmake --build build
```

### Running the Demo
Launch the executable directly in Windows Terminal, Command Prompt, or PowerShell:
```powershell
.\build\sertos_gaussian_demo.exe
```

### Interactive Controls
- **`[P]` or `[Space]`**: Pause or resume sample generation.
- **`[R]`**: Reset histogram bin counts and statistical moments to zero.
- **`[M]`**: Toggle between the compact stationary ANSI dashboard and the linear log stream mode (ideal for serial loggers / non-ANSI terminals).
- **`[Q]` or `[Esc]`**: Gracefully shut down the scheduler, restore terminal cursor, and exit.

---

## 4. Compilation & Execution (ARM Cortex-M33 / QEMU)

The demonstration supports bare-metal cross-compilation targeting the **ARM Cortex-M33** core (ARMv8-M Mainline with hardware FPU and `PSPLIM` stack limits) and executes directly in **QEMU** emulating the **ARM MPS2-AN505** board.

### Prerequisites
- GNU Arm Embedded Toolchain (`arm-none-eabi-gcc`, `arm-none-eabi-size`, e.g. `C:\arm\13.2.1\bin`)
- QEMU ARM System Emulator (`qemu-system-arm.exe`, e.g. `C:\Program Files\qemu`)
- Pre-compiled SertOS Cortex-M33 library (`../sertos/lib/arm/libsertos_cortex_m33.a`)

### Build Instructions
Run the automated build script:
```powershell
cd C:\github\sertos_gaussian_demo
.\build_m33.bat
```
This generates the standalone bare-metal ELF binary at:
```text
build\sertos_gaussian_demo_m33.elf
```

### Running over QEMU
Launch QEMU with the MPS2-AN505 machine profile using [`run_qemu.bat`](file:///C:/github/sertos_gaussian_demo/run_qemu.bat), which accepts the desired Cortex target and/or custom ELF path in any argument order:
```powershell
# Run default (Cortex-M33 / build\sertos_gaussian_demo_m33.elf)
.\run_qemu.bat

# Explicitly specify Cortex target
.\run_qemu.bat m33

# Specify custom ELF path
.\run_qemu.bat build\sertos_gaussian_demo_m33.elf

# Specify both ELF and Cortex target (any order)
.\run_qemu.bat build\sertos_gaussian_demo_m33.elf m33
.\run_qemu.bat m33 build\sertos_gaussian_demo_m33.elf

# Display help and supported targets
.\run_qemu.bat -h
```

Supported Cortex targets and corresponding QEMU machines:
- **`m33` / `cortex-m33`**: ARM MPS2-AN505 (ARMv8-M Mainline) `[Default]`
- **`m4` / `cortex-m4`**: ARM MPS2-AN386 (ARMv7E-M)
- **`m3` / `cortex-m3`**: ARM MPS2-AN385 (ARMv7-M)
- **`m7` / `cortex-m7`**: ARM MPS2-AN500 (ARMv7E-M)
- **`m0` / `cortex-m0`**: BBC micro:bit (ARMv6-M)

> [!TIP]
> **QEMU Control**: To terminate QEMU in non-graphical terminal mode, press `Ctrl+A` then `X`, or press `[Q]` in the demo UI.

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

