@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
pushd "%SCRIPT_DIR%"

:: -----------------------------------------------------------------------------
:: Parse Arguments (ELF file path and/or Cortex target)
:: Syntax: run_qemu.bat [cortex_type|elf_path] [elf_path|cortex_type]
:: -----------------------------------------------------------------------------
set "USER_ELF="
set "USER_CORTEX="
set "QEMU_MACHINE="
set "CORTEX_DESC="

for %%A in ("%~1" "%~2") do (
    if not "%%~A"=="" (
        if /i "%%~A"=="-h" goto :show_help
        if /i "%%~A"=="--help" goto :show_help
        if /i "%%~A"=="/?" goto :show_help

        if /i "%%~A"=="m33" (
            set "USER_CORTEX=m33"
        ) else if /i "%%~A"=="cortex-m33" (
            set "USER_CORTEX=m33"
        ) else if /i "%%~A"=="m4" (
            set "USER_CORTEX=m4"
        ) else if /i "%%~A"=="cortex-m4" (
            set "USER_CORTEX=m4"
        ) else if /i "%%~A"=="m3" (
            set "USER_CORTEX=m3"
        ) else if /i "%%~A"=="cortex-m3" (
            set "USER_CORTEX=m3"
        ) else if /i "%%~A"=="m7" (
            set "USER_CORTEX=m7"
        ) else if /i "%%~A"=="cortex-m7" (
            set "USER_CORTEX=m7"
        ) else if /i "%%~A"=="m0" (
            set "USER_CORTEX=m0"
        ) else if /i "%%~A"=="cortex-m0" (
            set "USER_CORTEX=m0"
        ) else if /i "%%~xA"==".elf" (
            set "USER_ELF=%%~A"
        ) else if exist "%%~A" (
            set "USER_ELF=%%~A"
        ) else (
            set "ARG_STR=%%~A"
            if /i "!ARG_STR:~0,4!"=="mps2" (
                set "QEMU_MACHINE=%%~A"
            ) else if /i "!ARG_STR:~0,4!"=="mps3" (
                set "QEMU_MACHINE=%%~A"
            ) else (
                set "USER_ELF=%%~A"
            )
        )
    )
)

:: Default Cortex target to m33 if not specified
if not defined USER_CORTEX (
    set "USER_CORTEX=m33"
)

:: Map Cortex target to QEMU machine profile
if "%USER_CORTEX%"=="m33" (
    if not defined QEMU_MACHINE set "QEMU_MACHINE=mps2-an505"
    set "CORTEX_DESC=Cortex-M33 (ARMv8-M Mainline)"
    if not defined USER_ELF set "USER_ELF=build\sertos_gaussian_demo_m33.elf"
) else if "%USER_CORTEX%"=="m4" (
    if not defined QEMU_MACHINE set "QEMU_MACHINE=mps2-an386"
    set "CORTEX_DESC=Cortex-M4 (ARMv7E-M)"
    if not defined USER_ELF set "USER_ELF=build\sertos_gaussian_demo_m4.elf"
) else if "%USER_CORTEX%"=="m3" (
    if not defined QEMU_MACHINE set "QEMU_MACHINE=mps2-an385"
    set "CORTEX_DESC=Cortex-M3 (ARMv7-M)"
    if not defined USER_ELF set "USER_ELF=build\sertos_gaussian_demo_m3.elf"
) else if "%USER_CORTEX%"=="m7" (
    if not defined QEMU_MACHINE set "QEMU_MACHINE=mps2-an500"
    set "CORTEX_DESC=Cortex-M7 (ARMv7E-M)"
    if not defined USER_ELF set "USER_ELF=build\sertos_gaussian_demo_m7.elf"
) else if "%USER_CORTEX%"=="m0" (
    if not defined QEMU_MACHINE set "QEMU_MACHINE=microbit"
    set "CORTEX_DESC=Cortex-M0 (ARMv6-M)"
    if not defined USER_ELF set "USER_ELF=build\sertos_gaussian_demo_m0.elf"
) else (
    if not defined QEMU_MACHINE set "QEMU_MACHINE=mps2-an505"
    set "CORTEX_DESC=Generic ARM (%USER_CORTEX%)"
    if not defined USER_ELF set "USER_ELF=build\sertos_gaussian_demo_m33.elf"
)

:: -----------------------------------------------------------------------------
:: Check or Auto-build ELF File
:: -----------------------------------------------------------------------------
if not exist "%USER_ELF%" (
    if /i "%USER_ELF%"=="build\sertos_gaussian_demo_m33.elf" (
        echo [INFO] %USER_ELF% does not exist. Building now via build_m33.bat...
        call build_m33.bat
        if not exist "%USER_ELF%" (
            echo [ERROR] Build failed. Aborting.
            popd
            exit /b 1
        )
    ) else (
        echo [ERROR] Specified ELF file not found: %USER_ELF%
        popd
        exit /b 1
    )
)

:: -----------------------------------------------------------------------------
:: Locate QEMU ARM Emulator
:: -----------------------------------------------------------------------------
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
    popd
    exit /b 1
)

echo ============================================================
echo [QEMU] Launching Target Binary in Emulator
echo [QEMU] Binary:  %USER_ELF%
echo [QEMU] Target:  %CORTEX_DESC%
echo [QEMU] Machine: %QEMU_MACHINE%
echo [QEMU] Press 'q' in console or Ctrl+A then X to terminate QEMU.
echo ============================================================
echo.
mode con: cols=85 lines=30 >nul 2>&1

"%QEMU_BIN%" -machine %QEMU_MACHINE% -nographic -semihosting -no-reboot -kernel "%USER_ELF%"

popd
endlocal
goto :eof

:: -----------------------------------------------------------------------------
:: Help Usage
:: -----------------------------------------------------------------------------
:show_help
echo.
echo Usage: run_qemu.bat [ELF_FILE] [CORTEX_TARGET]
echo        run_qemu.bat [CORTEX_TARGET] [ELF_FILE]
echo.
echo Arguments:
echo   ELF_FILE        Path to the compiled .elf binary.
echo                   (Default: build\sertos_gaussian_demo_m33.elf)
echo   CORTEX_TARGET   Target core or machine name. Supported options:
echo                     m33 / cortex-m33  (QEMU machine: mps2-an505) [Default]
echo                     m4  / cortex-m4   (QEMU machine: mps2-an386)
echo                     m3  / cortex-m3   (QEMU machine: mps2-an385)
echo                     m7  / cortex-m7   (QEMU machine: mps2-an500)
echo                     m0  / cortex-m0   (QEMU machine: microbit)
echo.
echo Examples:
echo   run_qemu.bat
echo   run_qemu.bat m33
echo   run_qemu.bat build\sertos_gaussian_demo_m33.elf
echo   run_qemu.bat build\sertos_gaussian_demo_m33.elf m33
echo   run_qemu.bat m33 build\sertos_gaussian_demo_m33.elf
echo.
popd
endlocal
