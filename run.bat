@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
pushd "%SCRIPT_DIR%"

:: -----------------------------------------------------------------------------
:: Parse Arguments
:: Syntax: run.bat [host|windows|posix|linux|m0|m3|m4|m33|path_to_binary]
:: -----------------------------------------------------------------------------
set "TARGET_MODE="
set "USER_FILE="

for %%A in (%*) do (
    if /i "%%~A"=="-h" goto :show_help
    if /i "%%~A"=="--help" goto :show_help
    if /i "%%~A"=="/?" goto :show_help

    if /i "%%~A"=="host" (
        set "TARGET_MODE=windows"
    ) else if /i "%%~A"=="windows" (
        set "TARGET_MODE=windows"
    ) else if /i "%%~A"=="win" (
        set "TARGET_MODE=windows"
    ) else if /i "%%~A"=="posix" (
        set "TARGET_MODE=posix"
    ) else if /i "%%~A"=="linux" (
        set "TARGET_MODE=posix"
    ) else if /i "%%~A"=="m33" (
        set "TARGET_MODE=m33"
    ) else if /i "%%~A"=="cortex-m33" (
        set "TARGET_MODE=m33"
    ) else if /i "%%~A"=="m4" (
        set "TARGET_MODE=m4"
    ) else if /i "%%~A"=="cortex-m4" (
        set "TARGET_MODE=m4"
    ) else if /i "%%~A"=="m3" (
        set "TARGET_MODE=m3"
    ) else if /i "%%~A"=="cortex-m3" (
        set "TARGET_MODE=m3"
    ) else if /i "%%~A"=="m0" (
        set "TARGET_MODE=m0"
    ) else if /i "%%~A"=="cortex-m0" (
        set "TARGET_MODE=m0"
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
if not defined USER_FILE set "USER_FILE=build\sertos_gaussian_demo.exe"

if not exist "!USER_FILE!" (
    echo [INFO] !USER_FILE! not found. Auto-building via build.bat windows...
    call build.bat windows
    if not exist "!USER_FILE!" (
        echo [ERROR] Build failed. Aborting.
        exit /b 1
    )
)

echo ============================================================
echo [RUN] Launching SertOS Gaussian Demo (Windows Host)
echo [RUN] Binary: !USER_FILE!
echo ============================================================
echo.
"!USER_FILE!"
exit /b %ERRORLEVEL%

:: -----------------------------------------------------------------------------
:: Subroutine: Run POSIX Target
:: -----------------------------------------------------------------------------
:run_posix
echo ============================================================
echo [RUN] SertOS Gaussian Demo (POSIX / Linux Target)
echo ============================================================
where wsl.exe >nul 2>nul
if not errorlevel 1 (
    echo [INFO] Windows Subsystem for Linux [WSL] detected.
    echo [INFO] Compiling POSIX demo inside WSL...
    wsl bash -c "cd /mnt/c/github/sertos && cmake -B build_posix -DCMAKE_BUILD_TYPE=Release && cmake --build build_posix && cd /mnt/c/github/sertos_gaussian_demo && cmake -B build_posix -DCMAKE_BUILD_TYPE=Release && cmake --build build_posix"
    if errorlevel 1 (
        echo [ERROR] WSL compilation failed.
        exit /b 1
    )
    echo.
    echo ============================================================
    echo [RUN] Launching POSIX demo in WSL...
    echo [RUN] Press 'q' in console or Ctrl+C to exit.
    echo ============================================================
    echo.
    wsl /mnt/c/github/sertos_gaussian_demo/build_posix/sertos_gaussian_demo
    exit /b %ERRORLEVEL%
) else (
    echo [INFO] POSIX target is designed for Linux, macOS, or WSL.
    echo [INFO] To run on POSIX:
    echo.
    echo   cmake -B build
    echo   cmake --build build
    echo   ./build/sertos_gaussian_demo
    echo.
    exit /b 0
)

:: -----------------------------------------------------------------------------
:: Subroutine: Run ARM QEMU Target
:: -----------------------------------------------------------------------------
:run_qemu
set "CORTEX_ARCH=%~1"

if "%CORTEX_ARCH%"=="m33" (
    set "QEMU_MACHINE=mps2-an505"
    set "CORTEX_DESC=Cortex-M33 (ARMv8-M Mainline)"
    if not defined USER_FILE set "USER_FILE=build\sertos_gaussian_demo_m33.elf"
) else if "%CORTEX_ARCH%"=="m4" (
    set "QEMU_MACHINE=mps2-an386"
    set "CORTEX_DESC=Cortex-M4 (ARMv7E-M)"
    if not defined USER_FILE set "USER_FILE=build\sertos_gaussian_demo_m4.elf"
) else if "%CORTEX_ARCH%"=="m3" (
    set "QEMU_MACHINE=mps2-an385"
    set "CORTEX_DESC=Cortex-M3 (ARMv7-M)"
    if not defined USER_FILE set "USER_FILE=build\sertos_gaussian_demo_m3.elf"
) else if "%CORTEX_ARCH%"=="m0" (
    set "QEMU_MACHINE=mps2-an385"
    set "CORTEX_DESC=Cortex-M0 (ARMv6-M on MPS2)"
    if not defined USER_FILE set "USER_FILE=build\sertos_gaussian_demo_m0.elf"
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
if exist "C:\Program Files\qemu\qemu-system-arm.exe" (
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
    echo Please ensure QEMU is installed at C:\Program Files\qemu or in your PATH.
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
mode con: cols=85 lines=30 >nul 2>&1

"%QEMU_BIN%" -machine %QEMU_MACHINE% -nographic -semihosting -no-reboot -kernel "!USER_FILE!"
exit /b 0

:: -----------------------------------------------------------------------------
:: Help Usage
:: -----------------------------------------------------------------------------
:show_help
echo.
echo Usage: run.bat [TARGET] [BINARY_PATH]
echo.
echo Targets:
echo   host, windows  Run Windows host application (build\sertos_gaussian_demo.exe) [Default]
echo   posix, linux   Run POSIX / Linux environment instructions / WSL runner
echo   m33            Run ARM Cortex-M33 in QEMU   (build\sertos_gaussian_demo_m33.elf)
echo   m4             Run ARM Cortex-M4 in QEMU    (build\sertos_gaussian_demo_m4.elf)
echo   m3             Run ARM Cortex-M3 in QEMU    (build\sertos_gaussian_demo_m3.elf)
echo   m0             Run ARM Cortex-M0 in QEMU    (build\sertos_gaussian_demo_m0.elf)
echo.
echo Examples:
echo   run.bat
echo   run.bat windows
echo   run.bat posix
echo   run.bat m33
echo   run.bat m0
echo   run.bat build\sertos_gaussian_demo_m4.elf
echo.
popd
endlocal
