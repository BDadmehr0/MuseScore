REM @echo off
ECHO "MuseScore build"

SET ARTIFACTS_DIR=build.artifacts
SET INSTALL_DIR=../build.install
SET BUILD_NUMBER=""
SET CRASH_LOG_SERVER_URL=""
SET TARGET_PROCESSOR_BITS=64
SET BUILD_CRASHPAD_CLIENT=OFF
SET BUILD_WIN_PORTABLE=OFF
SET DOCKWIDGETS_V2=OFF
SET BUILD_WEBSOCKET=ON

:GETOPTS
IF /I "%1" == "-n" SET BUILD_NUMBER=%2 & SHIFT
IF /I "%1" == "-b" SET TARGET_PROCESSOR_BITS=%2 & SHIFT
IF /I "%1" == "--crash_log_url" SET CRASH_LOG_SERVER_URL=%2 & SET BUILD_CRASHPAD_CLIENT=ON & SHIFT & SHIFT
IF /I "%1" == "--portable" SET BUILD_WIN_PORTABLE=%2 & SHIFT
IF /I "%1" == "--dockwidgets_v2" SET DOCKWIDGETS_V2=%2 & SHIFT
IF /I "%1" == "--websocket" SET "BUILD_WEBSOCKET=%~2" & SHIFT
SHIFT
IF NOT "%1" == "" GOTO GETOPTS

IF %BUILD_NUMBER% == "" ( ECHO "error: not set BUILD_NUMBER" & EXIT /b 1)
IF /I "%BUILD_WEBSOCKET%" == "ON" ( SET "BUILD_WEBSOCKET=ON" ) ELSE (
IF /I "%BUILD_WEBSOCKET%" == "OFF" ( SET "BUILD_WEBSOCKET=OFF" ) ELSE (
    ECHO "error: --websocket must be ON or OFF, current value: %BUILD_WEBSOCKET%"
    EXIT /b 1
))
IF NOT %TARGET_PROCESSOR_BITS% == 64 (
    IF NOT %TARGET_PROCESSOR_BITS% == 32 (
        ECHO "error: not set TARGET_PROCESSOR_BITS, must be 32 or 64, current TARGET_PROCESSOR_BITS: %TARGET_PROCESSOR_BITS%"
        EXIT /b 1
    )
)

IF NOT EXIST "%ARTIFACTS_DIR%\env\build_mode.env" (
    ECHO "error: %ARTIFACTS_DIR%\env\build_mode.env not found"
    ECHO "Generate it first with: bash buildscripts/ci/tools/make_build_mode_env.sh -e workflow_dispatch -m stable"
    EXIT /b 1
)
SET /p BUILD_MODE=<%ARTIFACTS_DIR%\env\build_mode.env
IF "%BUILD_MODE%" == "" (
    ECHO "error: BUILD_MODE is empty (file %ARTIFACTS_DIR%\env\build_mode.env may be empty)"
    EXIT /b 1
)
SET "MUSE_APP_BUILD_MODE=dev"
IF %BUILD_MODE% == devel   ( SET "MUSE_APP_BUILD_MODE=dev" ) ELSE (
IF %BUILD_MODE% == nightly ( SET "MUSE_APP_BUILD_MODE=dev" ) ELSE (
IF %BUILD_MODE% == testing ( SET "MUSE_APP_BUILD_MODE=testing" ) ELSE (
IF %BUILD_MODE% == stable  ( SET "MUSE_APP_BUILD_MODE=release" ) ELSE (
    ECHO "error: unknown BUILD_MODE: %BUILD_MODE%"
    EXIT /b 1
))))

ECHO "MUSE_APP_BUILD_MODE: %MUSE_APP_BUILD_MODE%"
ECHO "BUILD_NUMBER: %BUILD_NUMBER%"
ECHO "TARGET_PROCESSOR_BITS: %TARGET_PROCESSOR_BITS%"
ECHO "CRASH_LOG_SERVER_URL: %CRASH_LOG_SERVER_URL%"
ECHO "BUILD_WIN_PORTABLE: %BUILD_WIN_PORTABLE%"
ECHO "BUILD_WEBSOCKET: %BUILD_WEBSOCKET%"

XCOPY "C:\musescore_dependencies" %CD% /E /I /Y
ECHO "Finished copy dependencies"

SET "JACK_DIR=C:\Program Files (x86)\Jack"
SET "PATH=%JACK_DIR%;%PATH%"

SET "MUSESCORE_BUILD_CONFIGURATION=app"
IF %BUILD_WIN_PORTABLE% == ON (
    SET INSTALL_DIR=../build.install/App/MuseScore
    SET "MUSESCORE_BUILD_CONFIGURATION=app-portable"
)

bash ./buildscripts/ci/tools/make_revision_env.sh 
IF NOT EXIST "%ARTIFACTS_DIR%\env\build_revision.env" (
    ECHO "error: %ARTIFACTS_DIR%\env\build_revision.env not found after running make_revision_env.sh"
    ECHO "Make sure bash (Git Bash / WSL) is available and the script completed successfully."
    EXIT /b 1
)
SET /p MUSESCORE_REVISION=<%ARTIFACTS_DIR%\env\build_revision.env
IF "%MUSESCORE_REVISION%" == "" (
    ECHO "error: MUSESCORE_REVISION is empty"
    EXIT /b 1
)

SET MUSESCORE_BUILD_CONFIGURATION=%MUSESCORE_BUILD_CONFIGURATION%
SET MUSE_APP_BUILD_MODE=%MUSE_APP_BUILD_MODE%
SET MUSESCORE_BUILD_NUMBER=%BUILD_NUMBER%
SET MUSESCORE_REVISION=%MUSESCORE_REVISION%
SET MUSESCORE_INSTALL_DIR=%INSTALL_DIR%
SET MUSESCORE_CRASHREPORT_URL="%CRASH_LOG_SERVER_URL%"
SET MUSESCORE_BUILD_CRASHPAD_CLIENT=%BUILD_CRASHPAD_CLIENT%
SET "MUSESCORE_BUILD_VST_MODULE=ON"
REM Do NOT wrap these values in quotes: cmd keeps the quote characters in the
REM variable, ninja_build.sh passes them verbatim to CMake, and CMake treats
REM "OFF" (with quotes) as TRUE -> "Failed to find required Qt component WebSockets".
SET "MUSESCORE_BUILD_WEBSOCKET=%BUILD_WEBSOCKET%"
SET "MUSESCORE_RUN_WINDEPLOYQT=ON"
SET MUSESCORE_MODULE_DOCKWINDOW_KDDOCKWIDGETS_V2=%DOCKWIDGETS_V2%

CALL ninja_build.bat -t installrelwithdebinfo || exit \b 1

bash ./buildscripts/ci/tools/make_release_channel_env.sh -c %MUSE_APP_BUILD_MODE%
bash ./buildscripts/ci/tools/make_version_env.sh %BUILD_NUMBER%
bash ./buildscripts/ci/tools/make_branch_env.sh
