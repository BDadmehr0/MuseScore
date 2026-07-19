@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64

cd /d C:\Users\dadmehr\Desktop\MuseScore_BK\MuseScore

echo === CLEAN ===
rmdir /s /q build\Qt-Msvc-Debug
mkdir build\Qt-Msvc-Debug

echo === CONFIGURE ===
"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" --preset Qt-Msvc-Debug
if errorlevel 1 (
    echo CONFIGURE FAILED
    pause
    exit /b 1
)

echo === BUILD ===
"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" --build build\Qt-Msvc-Debug --target MuseScoreStudio --config Debug
if errorlevel 1 (
    echo BUILD FAILED
    pause
    exit /b 1
)

@REM echo === INSTALL ===
@REM "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" --install build\Qt-Msvc-Debug --config Debug

@REM echo === DONE ===
@REM pause