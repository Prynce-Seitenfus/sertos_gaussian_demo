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
        ) else if /i "%%~A"=="win" (
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
        ) else if /i "%%~A"=="riscv" (
            set "CHOSEN_TARGET=riscv"
        ) else if /i "%%~A"=="rv32i" (
            set "CHOSEN_TARGET=rv32i"
        ) else if /i "%%~A"=="rv32imc" (
            set "CHOSEN_TARGET=rv32imc"
        ) else if /i "%%~A"=="rv32imac" (
            set "CHOSEN_TARGET=rv32imac"
        ) else if /i "%%~A"=="rv32imafc" (
            set "CHOSEN_TARGET=rv32imafc"
        ) else if exist "%%~A\bin\gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A\bin"
        ) else if exist "%%~A\gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A"
        ) else if exist "%%~A\bin\arm-none-eabi-gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A\bin"
        ) else if exist "%%~A\arm-none-eabi-gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A"
        ) else if exist "%%~A\bin\riscv-none-elf-gcc.exe" (
            set "CUSTOM_TOOLCHAIN=%%~A\bin"
        ) else if exist "%%~A\riscv-none-elf-gcc.exe" (
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
if not exist "build\posix" mkdir "build\posix"
if not exist "build\riscv" mkdir "build\riscv"

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
    call :build_posix_wsl
) else if "%CHOSEN_TARGET%"=="posix" (
    call :build_posix_wsl
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
) else if "%CHOSEN_TARGET%"=="riscv" (
    call :build_riscv_single rv32i    rv32i_zicsr    ilp32
    call :build_riscv_single rv32imc  rv32imc_zicsr  ilp32
    call :build_riscv_single rv32imac rv32imac_zicsr ilp32
    call :build_riscv_single rv32imafc rv32imafc_zicsr ilp32f
) else if "%CHOSEN_TARGET%"=="rv32i" (
    call :build_riscv_single rv32i    rv32i_zicsr    ilp32
) else if "%CHOSEN_TARGET%"=="rv32imc" (
    call :build_riscv_single rv32imc  rv32imc_zicsr  ilp32
) else if "%CHOSEN_TARGET%"=="rv32imac" (
    call :build_riscv_single rv32imac rv32imac_zicsr ilp32
) else if "%CHOSEN_TARGET%"=="rv32imafc" (
    call :build_riscv_single rv32imafc rv32imafc_zicsr ilp32f
) else if "%CHOSEN_TARGET%"=="all" (
    call :build_host_app
    call :build_posix_wsl
    call :build_arm_all
    call :build_riscv_single rv32i    rv32i_zicsr    ilp32
    call :build_riscv_single rv32imc  rv32imc_zicsr  ilp32
    call :build_riscv_single rv32imac rv32imac_zicsr ilp32
    call :build_riscv_single rv32imafc rv32imafc_zicsr ilp32f
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
set "PATH=%HOST_TOOLCHAIN%;%PATH%"

set "SERTOS_HOST_LIB=%SERTOS_DIR%\lib\mingw64\libsertos_mingw64.a"
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
    echo [ERROR] Compiler or linker failed while building %TARGET_EXE%. See the diagnostic above.
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
:: Subroutine: Build POSIX Host Target Through WSL
:: -----------------------------------------------------------------------------
:build_posix_wsl
where wsl.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] WSL was not found. Install and initialize WSL to build the POSIX demo.
    set "BUILD_FAIL=1"
    goto :eof
)

echo.
echo ============================================================
echo [BUILD] Compiling Gaussian demo for native POSIX through WSL...
echo [SOURCE] %SCRIPT_DIR%
echo [TOOLCHAIN] WSL native Linux (gcc, ar, size)
echo ============================================================

wsl.exe --cd "%SCRIPT_DIR%" -- bash ./build.sh
if errorlevel 1 (
    echo [ERROR] Native POSIX demo build failed in WSL.
    set "BUILD_FAIL=1"
    goto :eof
)

echo [SUCCESS] Native POSIX demo build completed.
goto :eof

:: -----------------------------------------------------------------------------
:: Subroutine: Build RISC-V Application (single ISA profile)
:: Usage: call :build_riscv_single <profile> <march> <mabi>
::   profile = rv32i | rv32imc | rv32imac | rv32imafc
::   march   = rv32i_zicsr | rv32imc_zicsr | rv32imac_zicsr | rv32imafc_zicsr
::   mabi    = ilp32 | ilp32f
:: -----------------------------------------------------------------------------
:build_riscv_single
set "RISCV_PROFILE=%~1"
set "RISCV_MARCH=%~2"
set "RISCV_MABI=%~3"
set "RISCV_TOOLCHAIN="

if defined CUSTOM_TOOLCHAIN (
    if exist "%CUSTOM_TOOLCHAIN%\riscv-none-elf-gcc.exe" set "RISCV_TOOLCHAIN=%CUSTOM_TOOLCHAIN%"
)

if not defined RISCV_TOOLCHAIN (
    if exist "C:\toolchains\riscv\13.2.0\bin\riscv-none-elf-gcc.exe" (
        set "RISCV_TOOLCHAIN=C:\toolchains\riscv\13.2.0\bin"
    ) else if exist "C:\riscv\13.2.0\bin\riscv-none-elf-gcc.exe" (
        set "RISCV_TOOLCHAIN=C:\riscv\13.2.0\bin"
    )
)

if not defined RISCV_TOOLCHAIN (
    where riscv-none-elf-gcc.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where riscv-none-elf-gcc.exe') do (
            if not defined RISCV_TOOLCHAIN set "RISCV_TOOLCHAIN=%%~dpI"
        )
    )
)

if not defined RISCV_TOOLCHAIN (
    echo [ERROR] GNU RISC-V Embedded Toolchain not found!
    set "BUILD_FAIL=1"
    goto :eof
)

if "%RISCV_TOOLCHAIN:~-1%"=="\" set "RISCV_TOOLCHAIN=%RISCV_TOOLCHAIN:~0,-1%"

set "RISCV_CC=%RISCV_TOOLCHAIN%\riscv-none-elf-gcc.exe"
set "RISCV_SIZE=%RISCV_TOOLCHAIN%\riscv-none-elf-size.exe"

set "SERTOS_RISCV_LIB=%SERTOS_DIR%\lib\riscv\libsertos_%RISCV_PROFILE%.a"

if not exist "!SERTOS_RISCV_LIB!" (
    echo [INFO] SertOS RISC-V library not found. Auto-building now...
    pushd "%SERTOS_DIR%"
    call build.bat %RISCV_PROFILE% "%RISCV_TOOLCHAIN%"
    popd
    if not exist "!SERTOS_RISCV_LIB!" (
        echo [ERROR] Failed to compile !SERTOS_RISCV_LIB!
        set "BUILD_FAIL=1"
        goto :eof
    )
)

set "TARGET_ELF=build\riscv\sertos_gaussian_demo_%RISCV_PROFILE%.elf"
set "LDSCRIPT=bsp\riscv_virt.ld"

echo.
echo ============================================================
echo [BUILD] Compiling RISC-V Target: %TARGET_ELF%
echo [TOOLCHAIN] %RISCV_TOOLCHAIN%
echo ============================================================

set "RISCV_SRCS=%APP_CORE_SRCS% src\bsp\bsp_console_uart_stub.c src\bsp\startup_riscv.c"
set "RISCV_CFLAGS=-march=%RISCV_MARCH% -mabi=%RISCV_MABI% -O2 -Wall -Wextra -std=c99 -ffunction-sections -fdata-sections"
set "RISCV_SPECS=--specs=nano.specs -u _printf_float -nostartfiles"

"%RISCV_CC%" %RISCV_CFLAGS% %RISCV_SPECS% %COMMON_INCLUDES% -Wl,--gc-sections -T %LDSCRIPT% %RISCV_SRCS% "!SERTOS_RISCV_LIB!" -lm -o "!TARGET_ELF!"
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Failed compiling !TARGET_ELF!
    set "BUILD_FAIL=1"
    goto :eof
)

echo [SUCCESS] Generated: !TARGET_ELF!
if exist "%RISCV_SIZE%" (
    "%RISCV_SIZE%" -A "!TARGET_ELF!" | findstr /R /C:"Total" /C:".text" /C:".data" /C:".bss"
)
goto :eof

:: -----------------------------------------------------------------------------
:: Help Menu
:: -----------------------------------------------------------------------------
:show_help
echo.
echo Usage: build.bat [TARGET] [TOOLCHAIN_PATH]
echo.
echo Targets:
echo   all         Build host, all 8 ARM Cortex, and all 4 RISC-V binaries [Default]
echo   mingw64     Build MinGW-w64 host executable (build\mingw64\sertos_gaussian_demo.exe) [alias: windows]
echo   linux       Build POSIX host binary through WSL (build\posix\sertos_gaussian_demo) [alias: posix]
echo   arm         Build all 8 ARM Cortex binaries (build\arm\sertos_gaussian_demo_m*.elf)
echo   riscv       Build all 4 RISC-V binaries     (build\riscv\sertos_gaussian_demo_rv32*.elf)
echo   rv32i       Build RISC-V RV32I baseline     (build\riscv\sertos_gaussian_demo_rv32i.elf)      ilp32
echo   rv32imc     Build RISC-V RV32IMC            (build\riscv\sertos_gaussian_demo_rv32imc.elf)    ilp32
echo   rv32imac    Build RISC-V RV32IMAC           (build\riscv\sertos_gaussian_demo_rv32imac.elf)   ilp32
echo   rv32imafc   Build RISC-V RV32IMAFC FPU      (build\riscv\sertos_gaussian_demo_rv32imafc.elf) ilp32f
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
echo   build.bat riscv
echo   build.bat rv32imac
echo   build.bat rv32imafc
echo   build.bat m4
echo   build.bat riscv   C:\toolchains\riscv\13.2.0\bin
echo   build.bat arm     C:\toolchains\arm\13.2.1\bin
echo.
popd
endlocal
exit /b 0
