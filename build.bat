@echo off
setlocal

REM ============================================================================
REM  MuseScore Studio - build script (MSVC + Ninja + Qt)
REM
REM  Improved version of build.bat: sets up the Visual Studio environment,
REM  configures the project, builds, installs, copies the Persian Tuner plugin
REM  into the installed app, and (optionally) runs the app.
REM
REM  Usage:
REM    build.bat               incremental build + install + copy plugin + run
REM    build.bat clean         delete the build dir first (full rebuild)
REM    build.bat nobuild       skip the build (just install + copy plugin + run)
REM    build.bat norun         build + install but do not launch the app
REM
REM  Requirements:
REM    - Visual Studio 2022 with "Desktop development with C++"
REM      (found automatically via vswhere, no hardcoded path)
REM    - Qt 6.x for MSVC 2022 (x64). Set the Qt root in the QT_DIR env var,
REM      e.g.:  set QT_DIR=C:\Qt\6.10.2\msvc2022_64
REM      (or create a qt_env.bat in the repo root with that line)
REM    - CMake >= 3.27 (for preset schema v6) and Ninja on PATH
REM      (the CMake bundled with VS may be older - install a newer CMake if
REM      "Unknown Preset" / schema errors appear)
REM
REM  Optional:
REM    - Set RUN_WINDEPLOYQT=1 to deploy the Qt runtime DLLs next to the exe
REM      (only needed if the app fails to start with "Qt6Core.dll not found")
REM ============================================================================

set "ROOT=%~dp0"
set "PRESET=Qt-Msvc-Debug"
set "BUILD_DIR=%ROOT%build\%PRESET%"
set "INSTALL_DIR=%BUILD_DIR%\install"
set "APP_EXE=%INSTALL_DIR%\bin\MuseScoreStudio5.exe"

set "DO_CLEAN=0"
set "DO_BUILD=1"
set "DO_RUN=1"

if /I "%1"=="clean"   set "DO_CLEAN=1"
if /I "%1"=="nobuild" set "DO_BUILD=0"
if /I "%1"=="norun"   set "DO_RUN=0"

cd /d "%ROOT%"

echo.
echo ============================================================
echo   MuseScore Studio build
echo   Root:   %ROOT%
echo   Preset: %PRESET%
echo ============================================================

REM ---- Load optional local environment (e.g. QT_DIR) ----
if exist "%ROOT%qt_env.bat" (
    call "%ROOT%qt_env.bat"
)

if "%QT_DIR%"=="" (
    echo.
    echo WARNING: QT_DIR is not set. Configure will probably fail.
    echo Set it, e.g.:
    echo     set QT_DIR=C:\Qt\6.10.2\msvc2022_64
    echo (or put that line in a qt_env.bat in the repo root)
)

REM ---- [1/6] Visual Studio environment ----
echo.
echo [1/6] Setting up Visual Studio environment...
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo ERROR: vswhere.exe not found. Is Visual Studio installed?
    pause
    exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_INSTALL_DIR=%%i"

if not defined VS_INSTALL_DIR (
    echo ERROR: Visual Studio with C++ tools not found.
    pause
    exit /b 1
)
echo VS: %VS_INSTALL_DIR%
call "%VS_INSTALL_DIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 (
    echo ERROR: vcvars64.bat failed.
    pause
    exit /b 1
)

REM ---- [2/6] Clean (optional) ----
if "%DO_CLEAN%"=="1" (
    echo.
    echo [2/6] Cleaning build directory...
    if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
) else (
    echo.
    echo [2/6] Incremental build (add "clean" to rebuild from scratch)
)

REM ---- [3/6] Configure ----
echo.
echo [3/6] Configuring with preset "%PRESET%"...
if not exist "%BUILD_DIR%\CMakeCache.txt" (
    cmake --preset %PRESET%
    if errorlevel 1 (
        echo CONFIGURE FAILED
        pause
        exit /b 1
    )
) else (
    echo   (already configured, skipping)
)

REM ---- [4/6] Build ----
if "%DO_BUILD%"=="1" (
    echo.
    echo [4/6] Building MuseScoreStudio (Debug)...
    cmake --build "%BUILD_DIR%" --target MuseScoreStudio --config Debug
    if errorlevel 1 (
        echo BUILD FAILED
        pause
        exit /b 1
    )
) else (
    echo.
    echo [4/6] Build skipped ("nobuild")
)

REM ---- [5/6] Install ----
echo.
echo [5/6] Installing...
cmake --install "%BUILD_DIR%" --config Debug
if errorlevel 1 (
    echo INSTALL FAILED
    pause
    exit /b 1
)

REM ---- Copy Persian Tuner plugin into the installed app ----
if exist "%ROOT%share\plugins\persian_tuner" (
    if not exist "%INSTALL_DIR%\share\plugins" mkdir "%INSTALL_DIR%\share\plugins"
    xcopy /E /I /Y "%ROOT%share\plugins\persian_tuner" "%INSTALL_DIR%\share\plugins\persian_tuner" >nul
    echo Persian Tuner plugin copied to %INSTALL_DIR%\share\plugins\persian_tuner
)

REM ---- Optional: deploy Qt runtime DLLs ----
if "%RUN_WINDEPLOYQT%"=="1" (
    if defined QT_DIR if exist "%QT_DIR%\bin\windeployqt.exe" if exist "%APP_EXE%" (
        echo Deploying Qt runtime with windeployqt...
        "%QT_DIR%\bin\windeployqt.exe" --debug "%APP_EXE%" >nul 2>&1
    )
)

REM ---- [6/6] Done ----
echo.
echo ============================================================
echo   BUILD DONE
echo ============================================================
if "%DO_RUN%"=="1" (
    if exist "%APP_EXE%" (
        start "" "%APP_EXE%"
    ) else (
        echo App not found: %APP_EXE%
    )
)

endlocal
