@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
pushd "%SCRIPT_DIR%"

:: -----------------------------------------------------------------------------
:: Parse Arguments
:: Syntax: build.bat [all|host|windows|posix|arm|m0|m0plus|m3|m4|m7|m23|m33|m55] [toolchain_path]
:: -----------------------------------------------------------------------------
set "CHOSEN_TARGET="
set "CUSTOM_TOOLCHAIN="

for %%A in ("%~1" "%~2") do (
    if not "%%~A"=="" (
        if /i "%%~A"=="-h" goto :show_help
        if /i "%%~A"=="--help" goto :show_help
        if /i "%%~A"=="/?" goto :show_help

        if /i "%%~A"=="host" (
            set "CHOSEN_TARGET=host"
        ) else if /i "%%~A"=="mingw64" (
            set "CHOSEN_TARGET=mingw64"
        ) else if /i "%%~A"=="windows" (
            set "CHOSEN_TARGET=mingw64"
        ) else if /i "%%~A"=="linux" (
            set "CHOSEN_TARGET=linux"
        ) else if /i "%%~A"=="posix" (
            set "CHOSEN_TARGET=linux"
        ) else if /i "%%~A"=="arm" (
            set "CHOSEN_TARGET=arm"
        ) else if /i "%%~A"=="all" (
            set "CHOSEN_TARGET=all"
        ) else if /i "%%~A"=="cortex-m0" (
            set "CHOSEN_TARGET=cortex-m0"
        ) else if /i "%%~A"=="m0" (
            set "CHOSEN_TARGET=cortex-m0"
        ) else if /i "%%~A"=="cortex-m0plus" (
            set "CHOSEN_TARGET=cortex-m0plus"
        ) else if /i "%%~A"=="cortex-m0+" (
            set "CHOSEN_TARGET=cortex-m0plus"
        ) else if /i "%%~A"=="m0plus" (
            set "CHOSEN_TARGET=cortex-m0plus"
        ) else if /i "%%~A"=="m0+" (
            set "CHOSEN_TARGET=cortex-m0plus"
        ) else if /i "%%~A"=="cortex-m3" (
            set "CHOSEN_TARGET=cortex-m3"
        ) else if /i "%%~A"=="m3" (
            set "CHOSEN_TARGET=cortex-m3"
        ) else if /i "%%~A"=="cortex-m4" (
            set "CHOSEN_TARGET=cortex-m4"
        ) else if /i "%%~A"=="m4" (
            set "CHOSEN_TARGET=cortex-m4"
        ) else if /i "%%~A"=="cortex-m7" (
            set "CHOSEN_TARGET=cortex-m7"
        ) else if /i "%%~A"=="m7" (
            set "CHOSEN_TARGET=cortex-m7"
        ) else if /i "%%~A"=="cortex-m23" (
            set "CHOSEN_TARGET=cortex-m23"
        ) else if /i "%%~A"=="m23" (
            set "CHOSEN_TARGET=cortex-m23"
        ) else if /i "%%~A"=="cortex-m33" (
            set "CHOSEN_TARGET=cortex-m33"
        ) else if /i "%%~A"=="m33" (
            set "CHOSEN_TARGET=cortex-m33"
        ) else if /i "%%~A"=="cortex-m55" (
            set "CHOSEN_TARGET=cortex-m55"
        ) else if /i "%%~A"=="m55" (
            set "CHOSEN_TARGET=cortex-m55"
        ) else if exist "%%~A\bin\gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A\bin"
        ) else if exist "%%~A\gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A"
        ) else if exist "%%~A\bin\arm-none-eabi-gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A\bin"
        ) else if exist "%%~A\arm-none-eabi-gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A"
        )
    )
)

if not defined CHOSEN_TARGET (
    set "CHOSEN_TARGET=all"
)

:: -----------------------------------------------------------------------------
:: Common Paths and Build Directories
:: -----------------------------------------------------------------------------
if not exist "build" mkdir "build"
if not exist "build\mingw64" mkdir "build\mingw64"
if not exist "build\arm" mkdir "build\arm"
if not exist "build\linux" mkdir "build\linux"

set "SERTOS_DIR=..\sertos"
set "COMMON_INCLUDES=-Iinc -I%SERTOS_DIR%\inc -I%SERTOS_DIR%\port -I%SERTOS_DIR%\modules\ring_buffer -I%SERTOS_DIR%\modules\linked_list -I%SERTOS_DIR%\modules\bitmap -I%SERTOS_DIR%\modules\atomic"
set "APP_CORE_SRCS=src\main.c src\gaussian_math.c src\gaussian_state.c src\gaussian_tasks.c src\terminal_ui.c"

set "BUILD_FAIL=0"

:: -----------------------------------------------------------------------------
:: Execute Target Builds
:: -----------------------------------------------------------------------------
if "%CHOSEN_TARGET%"=="host" (
    call :build_host_app
) else if "%CHOSEN_TARGET%"=="mingw64" (
    call :build_host_app
) else if "%CHOSEN_TARGET%"=="windows" (
    call :build_host_app
) else if "%CHOSEN_TARGET%"=="linux" (
    call :build_posix_app
) else if "%CHOSEN_TARGET%"=="posix" (
    call :build_posix_app
) else if "%CHOSEN_TARGET%"=="arm" (
    call :build_arm_all
) else if "%CHOSEN_TARGET%"=="cortex-m0" (
    call :build_arm_single cortex-m0
) else if "%CHOSEN_TARGET%"=="cortex-m0plus" (
    call :build_arm_single cortex-m0plus
) else if "%CHOSEN_TARGET%"=="cortex-m3" (
    call :build_arm_single cortex-m3
) else if "%CHOSEN_TARGET%"=="cortex-m4" (
    call :build_arm_single cortex-m4
) else if "%CHOSEN_TARGET%"=="cortex-m7" (
    call :build_arm_single cortex-m7
) else if "%CHOSEN_TARGET%"=="cortex-m23" (
    call :build_arm_single cortex-m23
) else if "%CHOSEN_TARGET%"=="cortex-m33" (
    call :build_arm_single cortex-m33
) else if "%CHOSEN_TARGET%"=="cortex-m55" (
    call :build_arm_single cortex-m55
) else if "%CHOSEN_TARGET%"=="all" (
    call :build_host_app
    call :build_arm_all
)

echo.
echo ============================================================
if "!BUILD_FAIL!"=="0" (
    echo [SUCCESS] Build completed successfully
) else (
    echo [ERROR] Build completed with errors
)
echo ============================================================

if "!BUILD_FAIL!"=="0" (
    popd
    endlocal
    exit /b 0
) else (
    popd
    endlocal
    exit /b 1
)

:: -----------------------------------------------------------------------------
:: Subroutine: Build Host Windows Executable
:: -----------------------------------------------------------------------------
:build_host_app
set "HOST_TOOLCHAIN="

if defined CUSTOM_TOOLCHAIN (
    if exist "%CUSTOM_TOOLCHAIN%\gcc.exe" set "HOST_TOOLCHAIN=%CUSTOM_TOOLCHAIN%"
)

if not defined HOST_TOOLCHAIN (
    if exist "C:\toolchains\mingw64\13.2.0\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\toolchains\mingw64\13.2.0\bin"
    ) else if exist "C:\mingw64\gcc-13.2.0\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\mingw64\gcc-13.2.0\mingw64\bin"
    ) else if exist "C:\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\mingw64\bin"
    ) else if exist "C:\msys64\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\msys64\mingw64\bin"
    )
)

if not defined HOST_TOOLCHAIN (
    where gcc.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where gcc.exe') do (
            if not defined HOST_TOOLCHAIN set "HOST_TOOLCHAIN=%%~dpI"
        )
    )
)

if not defined HOST_TOOLCHAIN (
    echo [ERROR] MinGW / Host GCC toolchain not found!
    set "BUILD_FAIL=1"
    goto :eof
)

if "%HOST_TOOLCHAIN:~-1%"=="\" set "HOST_TOOLCHAIN=%HOST_TOOLCHAIN:~0,-1%"

set "HOST_CC=%HOST_TOOLCHAIN%\gcc.exe"
set "HOST_SIZE=%HOST_TOOLCHAIN%\size.exe"

set "SERTOS_HOST_LIB=%SERTOS_DIR%\lib\mingw64\libsertos_mingw64.a"
if not exist "!SERTOS_HOST_LIB!" set "SERTOS_HOST_LIB=%SERTOS_DIR%\lib\windows\libsertos_windows.a"
if not exist "!SERTOS_HOST_LIB!" (
    echo [INFO] SertOS MinGW-w64 host library not found. Building now...
    pushd "%SERTOS_DIR%"
    call build.bat mingw64 "%HOST_TOOLCHAIN%"
    popd
    if not exist "!SERTOS_HOST_LIB!" (
        echo [ERROR] Failed to compile !SERTOS_HOST_LIB!
        set "BUILD_FAIL=1"
        goto :eof
    )
)

set "TARGET_EXE=build\mingw64\sertos_gaussian_demo.exe"

echo.
echo ============================================================
echo [BUILD] Compiling Host Executable: %TARGET_EXE%
echo [TOOLCHAIN] %HOST_TOOLCHAIN%
echo ============================================================

set "HOST_SRCS=%APP_CORE_SRCS% src\bsp\bsp_console_windows.c"
set "HOST_CFLAGS=-O2 -Wall -Wextra -pedantic -std=c99"
set "HOST_LIBS="%SERTOS_HOST_LIB%" -lwinmm -lm"

"%HOST_CC%" %HOST_CFLAGS% %COMMON_INCLUDES% %HOST_SRCS% %HOST_LIBS% -o "%TARGET_EXE%"
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Failed compiling %TARGET_EXE%
    set "BUILD_FAIL=1"
    goto :eof
)

echo [SUCCESS] Generated: %TARGET_EXE%
if exist "%HOST_SIZE%" (
    "%HOST_SIZE%" "%TARGET_EXE%"
)
goto :eof

:: -----------------------------------------------------------------------------
:: Subroutine: Build All ARM Targets
:: -----------------------------------------------------------------------------
:build_arm_all
for %%T in (cortex-m0 cortex-m0plus cortex-m3 cortex-m4 cortex-m7 cortex-m23 cortex-m33 cortex-m55) do (
    call :build_arm_single %%T
)
goto :eof

:: -----------------------------------------------------------------------------
:: Subroutine: Build Single ARM Target
:: -----------------------------------------------------------------------------
:build_arm_single
set "ARM_TARGET=%~1"
set "ARM_TOOLCHAIN="

if defined CUSTOM_TOOLCHAIN (
    if exist "%CUSTOM_TOOLCHAIN%\arm-none-eabi-gcc.exe" set "ARM_TOOLCHAIN=%CUSTOM_TOOLCHAIN%"
)

if not defined ARM_TOOLCHAIN (
    if exist "C:\toolchains\arm\13.2.1\bin\arm-none-eabi-gcc.exe" (
        set "ARM_TOOLCHAIN=C:\toolchains\arm\13.2.1\bin"
    ) else if exist "C:\arm\13.2.1\bin\arm-none-eabi-gcc.exe" (
        set "ARM_TOOLCHAIN=C:\arm\13.2.1\bin"
    )
)

if not defined ARM_TOOLCHAIN (
    where arm-none-eabi-gcc.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where arm-none-eabi-gcc.exe') do (
            if not defined ARM_TOOLCHAIN set "ARM_TOOLCHAIN=%%~dpI"
        )
    )
)

if not defined ARM_TOOLCHAIN (
    echo [ERROR] GNU Arm Embedded Toolchain not found!
    set "BUILD_FAIL=1"
    goto :eof
)

if "%ARM_TOOLCHAIN:~-1%"=="\" set "ARM_TOOLCHAIN=%ARM_TOOLCHAIN:~0,-1%"

set "ARM_CC=%ARM_TOOLCHAIN%\arm-none-eabi-gcc.exe"
set "ARM_SIZE=%ARM_TOOLCHAIN%\arm-none-eabi-size.exe"

if "%ARM_TARGET%"=="cortex-m0" (
    set "ARCH_FLAGS=-mcpu=cortex-m0 -mthumb"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m0.elf"
    set "LDSCRIPT=bsp\mps2_generic.ld"
    set "LIB_NAME=libsertos_cortex_m0.a"
) else if "%ARM_TARGET%"=="cortex-m0plus" (
    set "ARCH_FLAGS=-mcpu=cortex-m0plus -mthumb"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m0plus.elf"
    set "LDSCRIPT=bsp\mps2_generic.ld"
    set "LIB_NAME=libsertos_cortex_m0plus.a"
) else if "%ARM_TARGET%"=="cortex-m3" (
    set "ARCH_FLAGS=-mcpu=cortex-m3 -mthumb"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m3.elf"
    set "LDSCRIPT=bsp\mps2_generic.ld"
    set "LIB_NAME=libsertos_cortex_m3.a"
) else if "%ARM_TARGET%"=="cortex-m4" (
    set "ARCH_FLAGS=-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m4.elf"
    set "LDSCRIPT=bsp\mps2_generic.ld"
    set "LIB_NAME=libsertos_cortex_m4.a"
) else if "%ARM_TARGET%"=="cortex-m7" (
    set "ARCH_FLAGS=-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m7.elf"
    set "LDSCRIPT=bsp\mps2_generic.ld"
    set "LIB_NAME=libsertos_cortex_m7.a"
) else if "%ARM_TARGET%"=="cortex-m23" (
    set "ARCH_FLAGS=-mcpu=cortex-m23 -mthumb"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m23.elf"
    set "LDSCRIPT=bsp\mps2_an505.ld"
    set "LIB_NAME=libsertos_cortex_m23.a"
) else if "%ARM_TARGET%"=="cortex-m33" (
    set "ARCH_FLAGS=-mcpu=cortex-m33 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m33.elf"
    set "LDSCRIPT=bsp\mps2_an505.ld"
    set "LIB_NAME=libsertos_cortex_m33.a"
) else if "%ARM_TARGET%"=="cortex-m55" (
    set "ARCH_FLAGS=-mcpu=cortex-m55 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard -DCONFIG_TARGET_CORTEX_M55=1"
    set "TARGET_ELF=build\arm\sertos_gaussian_demo_m55.elf"
    set "LDSCRIPT=bsp\mps3_an547.ld"
    set "LIB_NAME=libsertos_cortex_m55.a"
)

set "SERTOS_ARM_LIB=%SERTOS_DIR%\lib\arm\!LIB_NAME!"

if not exist "!SERTOS_ARM_LIB!" (
    echo [INFO] SertOS library !LIB_NAME! not found. Building now...
    pushd "%SERTOS_DIR%"
    call build.bat %ARM_TARGET% "%ARM_TOOLCHAIN%"
    popd
    if not exist "!SERTOS_ARM_LIB!" (
        echo [ERROR] Failed to compile !SERTOS_ARM_LIB!
        set "BUILD_FAIL=1"
        goto :eof
    )
)

echo.
echo ============================================================
echo [BUILD] Compiling ARM Target: !TARGET_ELF!
echo [TOOLCHAIN] %ARM_TOOLCHAIN%
echo ============================================================

set "ARM_SRCS=%APP_CORE_SRCS% src\bsp\bsp_console_uart_stub.c src\bsp\startup_arm_cortex_m.c"
set "ARM_CFLAGS=-O2 -Wall -Wextra -std=c99 -ffunction-sections -fdata-sections"
set "ARM_SPECS=--specs=nano.specs -u _printf_float"

"%ARM_CC%" !ARCH_FLAGS! %ARM_CFLAGS% %ARM_SPECS% %COMMON_INCLUDES% -Wl,--gc-sections -T !LDSCRIPT! %ARM_SRCS% "!SERTOS_ARM_LIB!" -lm -o "!TARGET_ELF!"
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Failed compiling !TARGET_ELF!
    set "BUILD_FAIL=1"
    goto :eof
)

echo [SUCCESS] Generated: !TARGET_ELF!
if exist "%ARM_SIZE%" (
    "%ARM_SIZE%" -A "!TARGET_ELF!" | findstr /R /C:"Total" /C:".text" /C:".data" /C:".bss"
)
goto :eof

:: -----------------------------------------------------------------------------
:: Subroutine: Build POSIX Host Target
:: -----------------------------------------------------------------------------
:build_posix_app
set "HOST_TOOLCHAIN="

if defined CUSTOM_TOOLCHAIN (
    if exist "%CUSTOM_TOOLCHAIN%\gcc.exe" set "HOST_TOOLCHAIN=%CUSTOM_TOOLCHAIN%"
)

if not defined HOST_TOOLCHAIN (
    if exist "C:\toolchains\mingw64\13.2.0\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\toolchains\mingw64\13.2.0\bin"
    ) else if exist "C:\mingw64\gcc-13.2.0\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\mingw64\gcc-13.2.0\mingw64\bin"
    ) else if exist "C:\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\mingw64\bin"
    ) else if exist "C:\msys64\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN=C:\msys64\mingw64\bin"
    )
)

if not defined HOST_TOOLCHAIN (
    where gcc.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where gcc.exe') do (
            if not defined HOST_TOOLCHAIN set "HOST_TOOLCHAIN=%%~dpI"
        )
    )
)

if not defined HOST_TOOLCHAIN (
    echo [ERROR] MinGW / Host GCC toolchain not found!
    set "BUILD_FAIL=1"
    goto :eof
)

if "%HOST_TOOLCHAIN:~-1%"=="\" set "HOST_TOOLCHAIN=%HOST_TOOLCHAIN:~0,-1%"

set "SERTOS_POSIX_LIB=%SERTOS_DIR%\lib\linux\libsertos_linux.a"
if not exist "!SERTOS_POSIX_LIB!" set "SERTOS_POSIX_LIB=%SERTOS_DIR%\lib\posix\libsertos_posix.a"
echo.
echo ============================================================
echo [BUILD] Building SertOS Linux Host Library...
echo [TOOLCHAIN] %HOST_TOOLCHAIN%
echo ============================================================
pushd "%SERTOS_DIR%"
call build.bat linux "%HOST_TOOLCHAIN%"
popd
if not exist "!SERTOS_POSIX_LIB!" (
    echo [ERROR] Failed to compile !SERTOS_POSIX_LIB!
    set "BUILD_FAIL=1"
    goto :eof
)

echo.
echo ============================================================
echo [SUCCESS] Linux kernel library ready: %SERTOS_POSIX_LIB%
echo [INFO] Full demo Linux binary build is supported natively on
echo        Linux / macOS / WSL using CMake or GCC termios:
echo        cmake -B build/linux && cmake --build build/linux
echo        On Windows host, build with: build.bat mingw64
echo ============================================================
goto :eof

:: -----------------------------------------------------------------------------
:: Help Menu
:: -----------------------------------------------------------------------------
:show_help
echo.
echo Usage: build.bat [TARGET] [TOOLCHAIN_PATH]
echo.
echo Targets:
echo   all         Build mingw64 host and all 8 ARM Cortex binaries [Default]
echo   mingw64     Build MinGW-w64 host executable (build\mingw64\sertos_gaussian_demo.exe) [alias: windows]
echo   linux       Build Linux host binary         (build\linux\sertos_gaussian_demo) [alias: posix]
echo   arm         Build all 8 ARM Cortex binaries (build\arm\sertos_gaussian_demo_m*.elf)
echo   m0          Build ARM Cortex-M0 binary      (build\arm\sertos_gaussian_demo_m0.elf)
echo   m0plus/m0+  Build ARM Cortex-M0+ binary     (build\arm\sertos_gaussian_demo_m0plus.elf)
echo   m3          Build ARM Cortex-M3 binary      (build\arm\sertos_gaussian_demo_m3.elf)
echo   m4          Build ARM Cortex-M4 binary      (build\arm\sertos_gaussian_demo_m4.elf)
echo   m7          Build ARM Cortex-M7 binary      (build\arm\sertos_gaussian_demo_m7.elf)
echo   m23         Build ARM Cortex-M23 binary     (build\arm\sertos_gaussian_demo_m23.elf)
echo   m33         Build ARM Cortex-M33 binary     (build\arm\sertos_gaussian_demo_m33.elf)
echo   m55         Build ARM Cortex-M55 binary     (build\arm\sertos_gaussian_demo_m55.elf)
echo.
echo Examples:
echo   build.bat
echo   build.bat mingw64
echo   build.bat linux
echo   build.bat arm
echo   build.bat m0
echo   build.bat m0plus
echo   build.bat m3
echo   build.bat m4
echo   build.bat m7
echo   build.bat m23
echo   build.bat m33
echo   build.bat m55
echo   build.bat windows C:\toolchains\mingw64\13.2.0\bin
echo   build.bat arm     C:\toolchains\arm\13.2.1\bin
echo.
popd
endlocal
