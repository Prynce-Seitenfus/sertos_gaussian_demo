@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
pushd "%SCRIPT_DIR%"

:: -----------------------------------------------------------------------------
:: Parse Arguments
:: Syntax: run.bat [host|windows|posix|linux|m0|m0plus|m3|m4|m7|m23|m33|m55|path_to_binary]
:: -----------------------------------------------------------------------------
set "TARGET_MODE="
set "USER_FILE="

for %%A in (%*) do (
    if /i "%%~A"=="-h" goto :show_help
    if /i "%%~A"=="--help" goto :show_help
    if /i "%%~A"=="/?" goto :show_help

    if /i "%%~A"=="host" (
        set "TARGET_MODE=windows"
    ) else if /i "%%~A"=="mingw64" (
        set "TARGET_MODE=windows"
    ) else if /i "%%~A"=="windows" (
        set "TARGET_MODE=windows"
    ) else if /i "%%~A"=="win" (
        set "TARGET_MODE=windows"
    ) else if /i "%%~A"=="posix" (
        set "TARGET_MODE=posix"
    ) else if /i "%%~A"=="linux" (
        set "TARGET_MODE=posix"
    ) else if /i "%%~A"=="m0" (
        set "TARGET_MODE=m0"
    ) else if /i "%%~A"=="cortex-m0" (
        set "TARGET_MODE=m0"
    ) else if /i "%%~A"=="m0plus" (
        set "TARGET_MODE=m0plus"
    ) else if /i "%%~A"=="m0+" (
        set "TARGET_MODE=m0plus"
    ) else if /i "%%~A"=="cortex-m0plus" (
        set "TARGET_MODE=m0plus"
    ) else if /i "%%~A"=="cortex-m0+" (
        set "TARGET_MODE=m0plus"
    ) else if /i "%%~A"=="m3" (
        set "TARGET_MODE=m3"
    ) else if /i "%%~A"=="cortex-m3" (
        set "TARGET_MODE=m3"
    ) else if /i "%%~A"=="m4" (
        set "TARGET_MODE=m4"
    ) else if /i "%%~A"=="cortex-m4" (
        set "TARGET_MODE=m4"
    ) else if /i "%%~A"=="m7" (
        set "TARGET_MODE=m7"
    ) else if /i "%%~A"=="cortex-m7" (
        set "TARGET_MODE=m7"
    ) else if /i "%%~A"=="m23" (
        set "TARGET_MODE=m23"
    ) else if /i "%%~A"=="cortex-m23" (
        set "TARGET_MODE=m23"
    ) else if /i "%%~A"=="m33" (
        set "TARGET_MODE=m33"
    ) else if /i "%%~A"=="cortex-m33" (
        set "TARGET_MODE=m33"
    ) else if /i "%%~A"=="m55" (
        set "TARGET_MODE=m55"
    ) else if /i "%%~A"=="cortex-m55" (
        set "TARGET_MODE=m55"
    ) else if /i "%%~A"=="riscv" (
        set "TARGET_MODE=rv32i"
    ) else if /i "%%~A"=="rv32i" (
        set "TARGET_MODE=rv32i"
    ) else if /i "%%~A"=="rv32imc" (
        set "TARGET_MODE=rv32imc"
    ) else if /i "%%~A"=="rv32imac" (
        set "TARGET_MODE=rv32imac"
    ) else if /i "%%~A"=="rv32imafc" (
        set "TARGET_MODE=rv32imafc"
    ) else if /i "%%~xA"==".exe" (
        set "TARGET_MODE=windows"
        set "USER_FILE=%%~A"
    ) else if /i "%%~xA"==".elf" (
        set "USER_FILE=%%~A"
    ) else if exist "%%~A" (
        set "USER_FILE=%%~A"
    )
)

if not defined TARGET_MODE (
    if defined USER_FILE (
        if /i "!USER_FILE:~-4!"==".elf" (
            set "TARGET_MODE=m33"
        ) else (
            set "TARGET_MODE=windows"
        )
    ) else (
        set "TARGET_MODE=windows"
    )
)

if "!TARGET_MODE!"=="windows" (
    call :run_windows
) else if "!TARGET_MODE!"=="posix" (
    call :run_posix
) else if "!TARGET_MODE!"=="rv32i" (
    call :run_qemu_riscv rv32i
) else if "!TARGET_MODE!"=="rv32imc" (
    call :run_qemu_riscv rv32imc
) else if "!TARGET_MODE!"=="rv32imac" (
    call :run_qemu_riscv rv32imac
) else if "!TARGET_MODE!"=="rv32imafc" (
    call :run_qemu_riscv rv32imafc
) else (
    call :run_qemu !TARGET_MODE!
)

set "EXIT_CODE=!ERRORLEVEL!"
popd
endlocal & exit /b %EXIT_CODE%

:: -----------------------------------------------------------------------------
:: Subroutine: Run Windows Host Target
:: -----------------------------------------------------------------------------
:run_windows
if not defined USER_FILE (
    if exist "build\mingw64\sertos_gaussian_demo.exe" (
        set "USER_FILE=build\mingw64\sertos_gaussian_demo.exe"
    ) else if exist "build\windows\sertos_gaussian_demo.exe" (
        set "USER_FILE=build\windows\sertos_gaussian_demo.exe"
    ) else if exist "build\sertos_gaussian_demo.exe" (
        set "USER_FILE=build\sertos_gaussian_demo.exe"
    ) else (
        set "USER_FILE=build\mingw64\sertos_gaussian_demo.exe"
    )
)

if not exist "!USER_FILE!" (
    echo [INFO] !USER_FILE! not found. Auto-building via build.bat mingw64...
    call build.bat mingw64
    if not exist "!USER_FILE!" (
        echo [ERROR] Build failed. Aborting.
        exit /b 1
    )
)

echo ============================================================
echo [RUN] Launching SertOS Gaussian Demo (MinGW-w64 / Windows Host)
echo [RUN] Binary: !USER_FILE!
echo ============================================================
echo.
"!USER_FILE!"
exit /b %ERRORLEVEL%

:: -----------------------------------------------------------------------------
:: Subroutine: Run POSIX / Linux Target
:: -----------------------------------------------------------------------------
:run_posix
echo ============================================================
echo [RUN] SertOS Gaussian Demo (Linux / POSIX Target)
echo ============================================================
where wsl.exe >nul 2>nul
if not errorlevel 1 (
    echo [INFO] Windows Subsystem for Linux [WSL] detected.
    echo [INFO] Compiling Linux demo inside WSL...
    wsl bash -c "cd /mnt/c/github/sertos && cmake -B build/linux -DCMAKE_BUILD_TYPE=Release && cmake --build build/linux && cd /mnt/c/github/sertos_gaussian_demo && cmake -B build/linux -DCMAKE_BUILD_TYPE=Release && cmake --build build/linux"
    if errorlevel 1 (
        echo [ERROR] WSL compilation failed.
        exit /b 1
    )
    echo.
    echo ============================================================
    echo [RUN] Launching Linux demo in WSL...
    echo [RUN] Press 'q' in console or Ctrl+C to exit.
    echo ============================================================
    echo.
    wsl /mnt/c/github/sertos_gaussian_demo/build/linux/sertos_gaussian_demo
    exit /b %ERRORLEVEL%
) else (
    echo [INFO] Linux / POSIX target is designed for Linux, macOS, or WSL.
    echo [INFO] To run on Linux:
    echo.
    echo   cmake -B build/linux
    echo   cmake --build build/linux
    echo   ./build/linux/sertos_gaussian_demo
    echo.
    exit /b 0
)

:: -----------------------------------------------------------------------------
:: Subroutine: Run ARM QEMU Target
:: -----------------------------------------------------------------------------
:run_qemu
set "CORTEX_ARCH=%~1"

if "%CORTEX_ARCH%"=="m0" (
    set "QEMU_MACHINE=mps2-an385"
    set "CORTEX_DESC=Cortex-M0 (ARMv6-M on MPS2)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m0.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m0.elf"
) else if "%CORTEX_ARCH%"=="m0plus" (
    set "QEMU_MACHINE=mps2-an385"
    set "CORTEX_DESC=Cortex-M0+ (ARMv6-M on MPS2)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m0plus.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m0plus.elf"
) else if "%CORTEX_ARCH%"=="m3" (
    set "QEMU_MACHINE=mps2-an385"
    set "CORTEX_DESC=Cortex-M3 (ARMv7-M)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m3.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m3.elf"
) else if "%CORTEX_ARCH%"=="m4" (
    set "QEMU_MACHINE=mps2-an386"
    set "CORTEX_DESC=Cortex-M4 (ARMv7E-M)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m4.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m4.elf"
) else if "%CORTEX_ARCH%"=="m7" (
    set "QEMU_MACHINE=mps2-an500"
    set "CORTEX_DESC=Cortex-M7 (ARMv7E-M DP-FPU)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m7.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m7.elf"
) else if "%CORTEX_ARCH%"=="m23" (
    set "QEMU_MACHINE=mps2-an505"
    set "CORTEX_DESC=Cortex-M23 (ARMv8-M Baseline)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m23.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m23.elf"
) else if "%CORTEX_ARCH%"=="m33" (
    set "QEMU_MACHINE=mps2-an505"
    set "CORTEX_DESC=Cortex-M33 (ARMv8-M Mainline)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m33.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m33.elf"
) else if "%CORTEX_ARCH%"=="m55" (
    set "QEMU_MACHINE=mps3-an547"
    set "CORTEX_DESC=Cortex-M55 (ARMv8.1-M Helium)"
    set "DEFAULT_ELF=build\arm\sertos_gaussian_demo_m55.elf"
    set "LEGACY_ELF=build\sertos_gaussian_demo_m55.elf"
)

if not defined USER_FILE (
    if exist "!DEFAULT_ELF!" (
        set "USER_FILE=!DEFAULT_ELF!"
    ) else if exist "!LEGACY_ELF!" (
        set "USER_FILE=!LEGACY_ELF!"
    ) else (
        set "USER_FILE=!DEFAULT_ELF!"
    )
)

if not exist "!USER_FILE!" (
    echo [INFO] !USER_FILE! not found. Auto-building via build.bat %CORTEX_ARCH%...
    call build.bat %CORTEX_ARCH%
    if not exist "!USER_FILE!" (
        echo [ERROR] Build failed. Aborting.
        exit /b 1
    )
)

set "QEMU_BIN="
if exist "C:\qemu\qemu-system-arm.exe" (
    set "QEMU_BIN=C:\qemu\qemu-system-arm.exe"
) else if exist "C:\Program Files\qemu\qemu-system-arm.exe" (
    set "QEMU_BIN=C:\Program Files\qemu\qemu-system-arm.exe"
) else (
    where qemu-system-arm.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where qemu-system-arm.exe') do (
            if not defined QEMU_BIN set "QEMU_BIN=%%~fI"
        )
    )
)

if not defined QEMU_BIN (
    echo [ERROR] qemu-system-arm.exe not found!
    echo Please ensure QEMU is installed at C:\qemu or in your PATH.
    exit /b 1
)

echo ============================================================
echo [QEMU] Launching SertOS Gaussian Demo in Emulator
echo [QEMU] Binary:  !USER_FILE!
echo [QEMU] Target:  %CORTEX_DESC%
echo [QEMU] Machine: %QEMU_MACHINE%
echo [QEMU] Press 'q' in console or Ctrl+A then X to terminate QEMU.
echo ============================================================
echo.

"%QEMU_BIN%" -machine %QEMU_MACHINE% -nographic -no-reboot -kernel "!USER_FILE!"
echo.
exit /b 0

:: -----------------------------------------------------------------------------
:: Subroutine: Run RISC-V QEMU Target
:: Usage: call :run_qemu_riscv <profile>
:: -----------------------------------------------------------------------------
:run_qemu_riscv
set "RISCV_PROFILE=%~1"
if not defined RISCV_PROFILE set "RISCV_PROFILE=rv32i"

set "DEFAULT_ELF=build\riscv\sertos_gaussian_demo_%RISCV_PROFILE%.elf"

if not defined USER_FILE (
    set "USER_FILE=!DEFAULT_ELF!"
)

if not exist "!USER_FILE!" (
    echo [INFO] !USER_FILE! not found. Auto-building via build.bat %RISCV_PROFILE%...
    call build.bat %RISCV_PROFILE%
    if not exist "!USER_FILE!" (
        echo [ERROR] Build failed. Aborting.
        exit /b 1
    )
)

set "QEMU_BIN="
if exist "C:\qemu\qemu-system-riscv32.exe" (
    set "QEMU_BIN=C:\qemu\qemu-system-riscv32.exe"
) else if exist "C:\Program Files\qemu\qemu-system-riscv32.exe" (
    set "QEMU_BIN=C:\Program Files\qemu\qemu-system-riscv32.exe"
) else (
    where qemu-system-riscv32.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where qemu-system-riscv32.exe') do (
            if not defined QEMU_BIN set "QEMU_BIN=%%~fI"
        )
    )
)

if not defined QEMU_BIN (
    echo [ERROR] qemu-system-riscv32.exe not found!
    echo Please ensure QEMU is installed at C:\qemu or in your PATH.
    exit /b 1
)

echo ============================================================
echo [QEMU] Launching SertOS Gaussian Demo in RISC-V Emulator
echo [QEMU] Binary:  !USER_FILE!
echo [QEMU] Target:  RISC-V %RISCV_PROFILE%
echo [QEMU] Machine: virt
echo [QEMU] Press 'q' in console or Ctrl+A then X to terminate QEMU.
echo ============================================================
echo.

"%QEMU_BIN%" -machine virt -bios none -nographic -no-reboot -kernel "!USER_FILE!"
echo.
exit /b 0


:: -----------------------------------------------------------------------------
:: Help Usage
:: -----------------------------------------------------------------------------
:show_help
echo.
echo Usage: run.bat [TARGET] [BINARY_PATH]
echo.
echo Targets:
echo   mingw64, windows Run MinGW-w64 host application (build\mingw64\sertos_gaussian_demo.exe) [Default]
echo   linux, posix    Run Linux / POSIX environment via WSL runner (build\linux\sertos_gaussian_demo)
echo   riscv, rv32i    Run RISC-V RV32I in QEMU          (build\riscv\sertos_gaussian_demo_rv32i.elf)
echo   rv32imc         Run RISC-V RV32IMC in QEMU        (build\riscv\sertos_gaussian_demo_rv32imc.elf)
echo   rv32imac        Run RISC-V RV32IMAC in QEMU       (build\riscv\sertos_gaussian_demo_rv32imac.elf)
echo   rv32imafc       Run RISC-V RV32IMAFC FPU in QEMU  (build\riscv\sertos_gaussian_demo_rv32imafc.elf)
echo   m0              Run ARM Cortex-M0 in QEMU         (build\arm\sertos_gaussian_demo_m0.elf)
echo   m0plus/m0+      Run ARM Cortex-M0+ in QEMU        (build\arm\sertos_gaussian_demo_m0plus.elf)
echo   m3              Run ARM Cortex-M3 in QEMU         (build\arm\sertos_gaussian_demo_m3.elf)
echo   m4              Run ARM Cortex-M4 in QEMU         (build\arm\sertos_gaussian_demo_m4.elf)
echo   m7              Run ARM Cortex-M7 in QEMU         (build\arm\sertos_gaussian_demo_m7.elf)
echo   m23             Run ARM Cortex-M23 in QEMU        (build\arm\sertos_gaussian_demo_m23.elf)
echo   m33             Run ARM Cortex-M33 in QEMU        (build\arm\sertos_gaussian_demo_m33.elf)
echo   m55             Run ARM Cortex-M55 in QEMU        (build\arm\sertos_gaussian_demo_m55.elf)
echo.
echo Examples:
echo   run.bat
echo   run.bat mingw64
echo   run.bat windows
echo   run.bat linux
echo   run.bat posix
echo   run.bat riscv
echo   run.bat rv32imc
echo   run.bat rv32imac
echo   run.bat rv32imafc
echo   run.bat m0
echo   run.bat m0plus
echo   run.bat m3
echo   run.bat m4
echo   run.bat m7
echo   run.bat m23
echo   run.bat m33
echo   run.bat m55
echo   run.bat build\riscv\sertos_gaussian_demo_rv32imac.elf
echo   run.bat build\arm\sertos_gaussian_demo_m4.elf
echo.
popd
endlocal
exit /b 0
