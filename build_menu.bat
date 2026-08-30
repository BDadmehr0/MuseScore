@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title MuseScore Build Menu

REM ============================================================================
REM  MuseScore Studio  -  Interactive build menu (Windows / MSVC)
REM
REM  Control how the project is built: Debug / Release / RelWithDebInfo,
REM  configure, build, install, run, clean. Choose from a menu, or pass
REM  command-line arguments for one-shot automation.
REM
REM  Usage:
REM    build_menu.bat                 -> interactive menu
REM    build_menu.bat -t Release      -> build+install+run in one shot
REM    build_menu.bat -c Release      -> configure only
REM    build_menu.bm help
REM ============================================================================

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

REM --- defaults ----------------------------------------------------------------
REM BUILD_TYPE: Debug, Release, or RelWithDebInfo
set "BUILD_TYPE=Debug"
set "DO_CONFIGURE=1"
set "DO_BUILD=1"
set "DO_INSTALL=1"
set "DO_RUN=0"
set "DO_CLEAN=0"
REM AUTO: 0 = interactive menu, 1 = run args once
set "AUTO=0"
set "JOBS="

REM --- find the top-level source dir (this folder) -----------------------------
if not exist "%ROOT%\CMakeLists.txt" (
    echo [ERROR] Could not find CMakeLists.txt in %ROOT%
    echo        Run this script from inside the MuseScore repository.
    pause
    exit /b 1
)

call :init_env
if errorlevel 1 (
    pause
    exit /b 1
)

REM --- command line args --------------------------------------------------------
if "%~1"=="" goto :menu
set "AUTO=1"
:parse_args
if "%~1"=="" goto :run_auto
if /i "%~1"=="-t" ( set "BUILD_TYPE=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="--target" ( set "BUILD_TYPE=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="-c" ( set "DO_BUILD=0" & set "DO_INSTALL=0" & set "BUILD_TYPE=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="--configure" ( set "DO_BUILD=0" & set "DO_INSTALL=0" & set "BUILD_TYPE=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="-j" ( set "JOBS=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="--jobs" ( set "JOBS=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="-b" ( set "DO_INSTALL=0" & set "DO_RUN=0" & shift & goto :parse_args )
if /i "%~1"=="--build-only" ( set "DO_INSTALL=0" & set "DO_RUN=0" & shift & goto :parse_args )
if /i "%~1"=="-n" ( set "DO_CONFIGURE=0" & shift & goto :parse_args )
if /i "%~1"=="--no-configure" ( set "DO_CONFIGURE=0" & shift & goto :parse_args )
if /i "%~1"=="-r" ( set "DO_RUN=1" & shift & goto :parse_args )
if /i "%~1"=="--run" ( set "DO_RUN=1" & shift & goto :parse_args )
if /i "%~1"=="-i" ( set "DO_CONFIGURE=0" & set "DO_BUILD=0" & set "DO_INSTALL=1" & shift & goto :parse_args )
if /i "%~1"=="--install-only" ( set "DO_CONFIGURE=0" & set "DO_BUILD=0" & set "DO_INSTALL=1" & shift & goto :parse_args )
if /i "%~1"=="--clean" ( set "DO_CLEAN=1" & shift & goto :parse_args )
if /i "%~1"=="help" ( call :show_help & exit /b 0 )
echo [WARN] Unknown argument: %~1
shift
goto :parse_args
:run_auto
call :do_all
exit /b %errorlevel%

REM ============================================================================
REM  Interactive menu
REM ============================================================================
:menu
cls
echo.
echo  ============================================================
echo   MuseScore Studio - Build Menu
echo  ============================================================
echo.
echo   Source : %ROOT%
echo   Qt dir : !QT_DIR!
echo.
echo   Current settings:
echo     Build type      : !BUILD_TYPE!
echo     Configure       : !DO_CONFIGURE!   (1=yes, 0=skip)
echo     Build           : !DO_BUILD!       (1=yes, 0=skip)
echo     Install         : !DO_INSTALL!     (1=yes, 0=skip)
echo     Run after build : !DO_RUN!         (1=yes, 0=no)
echo     Clean first     : !DO_CLEAN!       (1=yes, 0=no)
echo     Parallel jobs   : !JOBS!           (empty = auto)
echo.
echo  -------------------------------------------
echo   BUILD TYPE
echo  -------------------------------------------
echo   [1] Debug              [2] Release
echo   [3] RelWithDebInfo
echo  -------------------------------------------
echo   ACTIONS
echo  -------------------------------------------
echo   [4] Configure only
echo   [5] Build only (no install)
echo   [6] Install only
echo   [7] Build + Install (no run)
echo   [8] Build + Install + Run
echo  -------------------------------------------
echo   OTHER
echo  -------------------------------------------
echo   [9] Clean build directory (then exit)
echo   [C] Set parallel jobs
echo   [T] Toggle "Clean first"
echo   [Q] Quit
echo  -------------------------------------------
set /p "CHOICE=  Choose an option: "

if "%CHOICE%"=="1" ( set "BUILD_TYPE=Debug" & set "DO_CONFIGURE=1" & set "DO_BUILD=1" & set "DO_INSTALL=1" & set "DO_RUN=0" & call :do_all & goto :menu )
if "%CHOICE%"=="2" ( set "BUILD_TYPE=Release" & set "DO_CONFIGURE=1" & set "DO_BUILD=1" & set "DO_INSTALL=1" & set "DO_RUN=0" & call :do_all & goto :menu )
if "%CHOICE%"=="3" ( set "BUILD_TYPE=RelWithDebInfo" & set "DO_CONFIGURE=1" & set "DO_BUILD=1" & set "DO_INSTALL=1" & set "DO_RUN=0" & call :do_all & goto :menu )
if "%CHOICE%"=="4" ( set "DO_CONFIGURE=1" & set "DO_BUILD=0" & set "DO_INSTALL=0" & set "DO_RUN=0" & call :do_all & goto :menu )
if "%CHOICE%"=="5" ( set "DO_CONFIGURE=1" & set "DO_BUILD=1" & set "DO_INSTALL=0" & set "DO_RUN=0" & call :do_all & goto :menu )
if "%CHOICE%"=="6" ( set "DO_CONFIGURE=0" & set "DO_BUILD=0" & set "DO_INSTALL=1" & set "DO_RUN=0" & call :do_all & goto :menu )
if "%CHOICE%"=="7" ( set "DO_CONFIGURE=1" & set "DO_BUILD=1" & set "DO_INSTALL=1" & set "DO_RUN=0" & call :do_all & goto :menu )
if "%CHOICE%"=="8" ( set "DO_CONFIGURE=1" & set "DO_BUILD=1" & set "DO_INSTALL=1" & set "DO_RUN=1" & call :do_all & goto :menu )
if "%CHOICE%"=="9" ( call :clean & pause & exit /b 0 )
if /i "%CHOICE%"=="C" ( set /p "JOBS=  Enter parallel jobs (empty for auto): " & goto :menu )
if /i "%CHOICE%"=="T" ( if "!DO_CLEAN!"=="1" ( set "DO_CLEAN=0" ) else ( set "DO_CLEAN=1" ) & goto :menu )
if /i "%CHOICE%"=="Q" ( exit /b 0 )
echo.
echo  Invalid choice. Press any key to try again.
pause >nul
goto :menu

REM ============================================================================
REM  Set up environment: MSVC dev tools + Qt
REM ============================================================================
:init_env
REM --- MSVC developer environment via vswhere ---
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"

set "VSDEVCMD="
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do (
        if exist "%%i\VC\Auxiliary\Build\vcvars64.bat" set "VSDEVCMD=%%i\VC\Auxiliary\Build\vcvars64.bat"
    )
)

REM fallback: common known paths
if not defined VSDEVCMD (
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat" set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
    if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat" set "VSDEVCMD=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" set "VSDEVCMD=C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" set "VSDEVCMD=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
)

if not defined VSDEVCMD (
    echo [ERROR] Could not locate the MSVC developer environment (vcvars64.bat).
    echo         Install "Desktop development with C++" workload in Visual Studio.
    exit /b 1
)

echo [env] Loading MSVC environment: %VSDEVCMD%
call "%VSDEVCMD%"
if errorlevel 1 (
    echo [ERROR] Failed to load MSVC environment.
    exit /b 1
)

REM --- Qt directory ---
if defined QTDIR (
    set "QT_DIR=%QTDIR%"
) else (
    if defined QT_DIR (
        REM already set
    ) else (
        REM try to auto-detect the newest Qt msvc2022_64 installation
        if exist "C:\Qt" (
            set "QT_DIR="
            for /f "delims=" %%d in ('dir /b /ad /o-n "C:\Qt" 2^>nul') do (
                if not defined QT_DIR (
                    if exist "C:\Qt\%%d\msvc2022_64" set "QT_DIR=C:\Qt\%%d\msvc2022_64"
                )
            )
        )
    )
)

if not defined QT_DIR (
    echo [ERROR] Could not locate the Qt installation.
    echo         Set the QTDIR environment variable or QT_DIR before running.
    echo         Example:  set QT_DIR=C:\Qt\6.10.2\msvc2022_64
    exit /b 1
)
if not exist "%QT_DIR%\lib\cmake\Qt6\qt.toolchain.cmake" (
    echo [WARN] qt.toolchain.cmake not found under "%QT_DIR%".
    echo        Check that QT_DIR points to an MSVC Qt kit, e.g. C:\Qt\6.10.2\msvc2022_64
)
set "QT_DIR=%QT_DIR%"
echo [env] Qt dir: %QT_DIR%
exit /b 0

REM ============================================================================
REM  Map build type to a CMake preset + build dir
REM ============================================================================
:build_preset
if /i "%BUILD_TYPE%"=="Debug" ( set "PRESET=Qt-Msvc-Debug" & set "BUILD_DIR=build\Qt-Msvc-Debug" & exit /b 0 )
if /i "%BUILD_TYPE%"=="Release" ( set "PRESET=Qt-Msvc-Release" & set "BUILD_DIR=build\Qt-Msvc-Release" & exit /b 0 )
if /i "%BUILD_TYPE%"=="RelWithDebInfo" ( set "PRESET=Qt-Msvc-RelWithDebInfo" & set "BUILD_DIR=build\Qt-Msvc-RelWithDebInfo" & exit /b 0 )
echo [ERROR] Unknown build type: %BUILD_TYPE%
exit /b 1

REM ============================================================================
REM  Locate the built executable
REM ============================================================================
:find_exe
set "EXE="
for %%E in (
    "%ROOT%\!BUILD_DIR!\install\bin\MuseScoreStudio*.exe"
    "%ROOT%\!BUILD_DIR!\bin\MuseScoreStudio*.exe"
) do (
    if exist "%%E" set "EXE=%%E"
)
exit /b 0

REM ============================================================================
REM  Run the full pipeline (configure / build / install / run)
REM ============================================================================
:do_all
call :build_preset
if errorlevel 1 ( exit /b 1 )
echo.
echo  ============================================================
echo   Target : %BUILD_TYPE%     Preset : %PRESET%
echo   Build  : %ROOT%\%BUILD_DIR%
echo  ============================================================
echo.

REM --- clean ---
if "!DO_CLEAN!"=="1" (
    call :clean
)

REM --- configure ---
if "!DO_CONFIGURE!"=="1" (
    echo === [1/4] CONFIGURE ===
    cmake --preset !PRESET!
    if errorlevel 1 ( echo [ERROR] Configure failed. & exit /b 1 )
)

REM --- build ---
if "!DO_BUILD!"=="1" (
    echo === [2/4] BUILD ===
    if defined JOBS (
        cmake --build "!BUILD_DIR!" --target MuseScoreStudio -- -j !JOBS!
    ) else (
        cmake --build "!BUILD_DIR!" --target MuseScoreStudio
    )
    if errorlevel 1 ( echo [ERROR] Build failed. & exit /b 1 )
)

REM --- install ---
if "!DO_INSTALL!"=="1" (
    echo === [3/4] INSTALL ===
    cmake --install "!BUILD_DIR!"
    if errorlevel 1 ( echo [ERROR] Install failed. & exit /b 1 )
)

REM --- run ---
if "!DO_RUN!"=="1" (
    call :find_exe
    if defined EXE (
        echo === [4/4] RUN ===
        start "" "!EXE!"
    ) else (
        echo [WARN] Could not locate MuseScoreStudio.exe to run.
    )
)

echo.
echo  === ALL DONE ===
exit /b 0

REM ============================================================================
REM  Clean a build directory
REM ============================================================================
:clean
call :build_preset
if errorlevel 1 ( exit /b 1 )
echo === CLEAN ===
if exist "%ROOT%\!BUILD_DIR!" (
    rmdir /s /q "%ROOT%\!BUILD_DIR!"
    echo Removed %ROOT%\!BUILD_DIR!
) else (
    echo Nothing to clean: %ROOT%\!BUILD_DIR! does not exist.
)
exit /b 0

REM ============================================================================
REM  Help
REM ============================================================================
:show_help
echo.
echo  MuseScore Studio Build Menu
echo  ---------------------------
echo   Interactive:   build_menu.bat
echo.
echo   One-shot:
echo     build_menu.bat -t Debug            build+install Debug
echo     build_menu.bat -t Release          build+install Release
echo     build_menu.bat -t RelWithDebInfo   build+install RelWithDebInfo
echo     build_menu.bat -t Release -r       build+install+run Release
echo     build_menu.bat -c Debug            configure Debug only
echo     build_menu.bat -b Release          build only (no install)
echo     build_menu.bat -i                  install only
echo     build_menu.bat -j 8 -t Release     build with 8 parallel jobs
echo     build_menu.bat --clean -t Debug    clean then configure+build
echo     build_menu.bat help                this help
echo.
echo   Environment:
echo     QT_DIR  (or QTDIR)  Path to the Qt MSVC kit, e.g. C:\Qt\6.10.2\msvc2022_64
exit /b 0
