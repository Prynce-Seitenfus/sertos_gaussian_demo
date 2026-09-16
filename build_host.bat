@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
pushd "%SCRIPT_DIR%"

:: -----------------------------------------------------------------------------
:: Parse Arguments (Toolchain path or flags)
:: Syntax: build_host.bat [path\to\gcc\bin] [--run]
:: -----------------------------------------------------------------------------
set "HOST_TOOLCHAIN_BIN="
set "DO_RUN=0"

for %%A in ("%~1" "%~2") do (
    if not "%%~A"=="" (
        if /i "%%~A"=="--run" (
            set "DO_RUN=1"
        ) else if /i "%%~A"=="run" (
            set "DO_RUN=1"
        ) else if /i "%%~A"=="-r" (
            set "DO_RUN=1"
        ) else if /i "%%~A"=="-h" (
            goto :show_help
        ) else if /i "%%~A"=="--help" (
            goto :show_help
        ) else if /i "%%~A"=="/?" (
            goto :show_help
        ) else if exist "%%~A\bin\gcc.exe" (
            set "HOST_TOOLCHAIN_BIN=%%~A\bin"
        ) else if exist "%%~A\gcc.exe" (
            set "HOST_TOOLCHAIN_BIN=%%~A"
        )
    )
)

:: -----------------------------------------------------------------------------
:: Locate GCC / MinGW Toolchain
:: -----------------------------------------------------------------------------
if not defined HOST_TOOLCHAIN_BIN (
    if exist "C:\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN_BIN=C:\mingw64\bin"
    ) else if exist "C:\msys64\mingw64\bin\gcc.exe" (
        set "HOST_TOOLCHAIN_BIN=C:\msys64\mingw64\bin"
    )
)

if not defined HOST_TOOLCHAIN_BIN (
    where gcc.exe >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%I in ('where gcc.exe') do (
            if not defined HOST_TOOLCHAIN_BIN set "HOST_TOOLCHAIN_BIN=%%~dpI"
        )
    )
)

if not defined HOST_TOOLCHAIN_BIN (
    echo [ERROR] GCC toolchain not found!
    echo Please install MinGW-w64 or specify path, e.g.:
    echo   build_host.bat C:\mingw64\bin
    popd
    exit /b 1
)

if "%HOST_TOOLCHAIN_BIN:~-1%"=="\" set "HOST_TOOLCHAIN_BIN=%HOST_TOOLCHAIN_BIN:~0,-1%"

set "CC=%HOST_TOOLCHAIN_BIN%\gcc.exe"
set "SIZE=%HOST_TOOLCHAIN_BIN%\size.exe"

echo ============================================================
echo [HOST BUILD] Toolchain: %HOST_TOOLCHAIN_BIN%
"%CC%" --version | findstr /C:"gcc"
echo ============================================================

:: -----------------------------------------------------------------------------
:: Check or Auto-build SertOS Windows Host Library
:: -----------------------------------------------------------------------------
set "SERTOS_DIR=..\sertos"
set "SERTOS_LIB=%SERTOS_DIR%\lib\windows\libsertos_windows.a"

if not exist "%SERTOS_LIB%" (
    echo.
    echo [INFO] SertOS Windows library not found at:
    echo        %SERTOS_LIB%
    echo [INFO] Compiling SertOS host library now via %SERTOS_DIR%\build_host.bat...
    pushd "%SERTOS_DIR%"
    call build_host.bat windows "%HOST_TOOLCHAIN_BIN%"
    popd
    if not exist "%SERTOS_LIB%" (
        echo [ERROR] Failed to compile %SERTOS_LIB%
        popd
        exit /b 1
    )
)

:: -----------------------------------------------------------------------------
:: Compilation Configuration
:: -----------------------------------------------------------------------------
if not exist "build" mkdir "build"

set "TARGET_EXE=build\sertos_gaussian_demo.exe"

set "CFLAGS=-O2 -Wall -Wextra -pedantic -std=c99"
set "INCLUDES=-Iinc -I%SERTOS_DIR%\inc -I%SERTOS_DIR%\port -I%SERTOS_DIR%\modules\ring_buffer -I%SERTOS_DIR%\modules\linked_list -I%SERTOS_DIR%\modules\bitmap -I%SERTOS_DIR%\modules\atomic"
set "SRCS=src\main.c src\gaussian_math.c src\gaussian_state.c src\gaussian_tasks.c src\terminal_ui.c src\bsp\bsp_console_windows.c"
set "LIBS="%SERTOS_LIB%" -lwinmm -lm"

echo.
echo [HOST BUILD] Compiling %TARGET_EXE% ...
"%CC%" %CFLAGS% %INCLUDES% %SRCS% %LIBS% -o "%TARGET_EXE%"
if errorlevel 1 (
    echo [ERROR] Compilation failed!
    popd
    exit /b 1
)

echo.
echo ============================================================
echo [SUCCESS] Host executable generated successfully:
echo           %TARGET_EXE%
echo ============================================================
if exist "%SIZE%" (
    "%SIZE%" "%TARGET_EXE%"
)

if "%DO_RUN%"=="1" (
    echo.
    echo [INFO] Launching %TARGET_EXE% ...
    "%TARGET_EXE%"
)

popd
endlocal
goto :eof

:: -----------------------------------------------------------------------------
:: Help Usage
:: -----------------------------------------------------------------------------
:show_help
echo.
echo Usage: build_host.bat [TOOLCHAIN_PATH] [--run]
echo.
echo Options:
echo   TOOLCHAIN_PATH  Optional directory path to MinGW/GCC bin (e.g. C:\mingw64\bin)
echo   --run, run, -r  Automatically run the executable after successful build
echo   -h, --help      Display this help menu
echo.
echo Examples:
echo   build_host.bat
echo   build_host.bat --run
echo   build_host.bat C:\mingw64\bin
echo   build_host.bat C:\mingw64\bin --run
echo.
popd
endlocal
