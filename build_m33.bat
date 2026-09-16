@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
pushd "%SCRIPT_DIR%"

:: -----------------------------------------------------------------------------
:: Locate GNU Arm Embedded Toolchain
:: -----------------------------------------------------------------------------
set "ARM_TOOLCHAIN_BIN="

if not "%~1"=="" (
    if exist "%~1\bin\arm-none-eabi-gcc.exe" (
        set "ARM_TOOLCHAIN_BIN=%~1\bin"
    ) else if exist "%~1\arm-none-eabi-gcc.exe" (
        set "ARM_TOOLCHAIN_BIN=%~1"
    )
)

if not defined ARM_TOOLCHAIN_BIN (
    if exist "C:\arm\13.2.1\bin\arm-none-eabi-gcc.exe" (
        set "ARM_TOOLCHAIN_BIN=C:\arm\13.2.1\bin"
    )
)

if not defined ARM_TOOLCHAIN_BIN (
    where arm-none-eabi-gcc.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where arm-none-eabi-gcc.exe') do (
            if not defined ARM_TOOLCHAIN_BIN set "ARM_TOOLCHAIN_BIN=%%~dpI"
        )
    )
)

if not defined ARM_TOOLCHAIN_BIN (
    echo [ERROR] GNU Arm Embedded Toolchain not found!
    echo Please specify path, e.g.: build_m33.bat C:\arm\13.2.1
    popd
    exit /b 1
)

if "%ARM_TOOLCHAIN_BIN:~-1%"=="\" set "ARM_TOOLCHAIN_BIN=%ARM_TOOLCHAIN_BIN:~0,-1%"

set "CC=%ARM_TOOLCHAIN_BIN%\arm-none-eabi-gcc.exe"
set "SIZE=%ARM_TOOLCHAIN_BIN%\arm-none-eabi-size.exe"

echo ============================================================
echo [M33 BUILD] Toolchain: %ARM_TOOLCHAIN_BIN%
"%CC%" --version | findstr /C:"arm-none-eabi-gcc"
echo ============================================================

:: -----------------------------------------------------------------------------
:: Check SertOS Library for Cortex-M33
:: -----------------------------------------------------------------------------
set "SERTOS_DIR=..\sertos"
set "SERTOS_LIB=%SERTOS_DIR%\lib\arm\libsertos_cortex_m33.a"

if not exist "%SERTOS_LIB%" (
    echo [INFO] SertOS Cortex-M33 library not found. Building now...
    pushd "%SERTOS_DIR%"
    call build_arm.bat "%ARM_TOOLCHAIN_BIN%"
    popd
    if not exist "%SERTOS_LIB%" (
        echo [ERROR] Failed to find or build %SERTOS_LIB%
        popd
        exit /b 1
    )
)

:: -----------------------------------------------------------------------------
:: Compilation Configuration
:: -----------------------------------------------------------------------------
if not exist "build" mkdir "build"

set "TARGET_ELF=build\sertos_gaussian_demo_m33.elf"
set "LDSCRIPT=bsp\mps2_an505.ld"

set "ARCH_FLAGS=-mcpu=cortex-m33 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard"
set "CFLAGS=-O2 -Wall -Wextra -std=c99 -ffunction-sections -fdata-sections"
set "SPECS_FLAGS=--specs=nano.specs --specs=nosys.specs -u _printf_float"
set "LDFLAGS=-Wl,--gc-sections -T %LDSCRIPT%"

set "INCLUDES=-Iinc -I%SERTOS_DIR%\inc -I%SERTOS_DIR%\port -I%SERTOS_DIR%\modules\ring_buffer -I%SERTOS_DIR%\modules\linked_list -I%SERTOS_DIR%\modules\bitmap -I%SERTOS_DIR%\modules\atomic"

set "SRCS=src\main.c src\gaussian_math.c src\gaussian_state.c src\gaussian_tasks.c src\terminal_ui.c src\bsp\bsp_console_uart_stub.c src\bsp\startup_arm_cortex_m.c"

echo.
echo [M33 BUILD] Compiling %TARGET_ELF% ...
"%CC%" %ARCH_FLAGS% %CFLAGS% %SPECS_FLAGS% %INCLUDES% %LDFLAGS% %SRCS% "%SERTOS_LIB%" -lm -o "%TARGET_ELF%"
if errorlevel 1 (
    echo [ERROR] Compilation failed!
    popd
    exit /b 1
)

echo.
echo ============================================================
echo [SUCCESS] Binary generated successfully:
echo           %TARGET_ELF%
echo ============================================================
if exist "%SIZE%" (
    "%SIZE%" -A "%TARGET_ELF%"
)

popd
endlocal
