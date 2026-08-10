@echo off
setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
if errorlevel 1 (
echo VS DEV CMD FAILED
pause
exit /b 1
)

cd /d "C:\Users\dadmehr\Desktop\MuseScore_BK\MuseScore"

set CMAKE="C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set BUILD_DIR=build\Qt-Msvc-Debug
set INSTALL_DIR=%CD%%BUILD_DIR%\install

echo.
echo ========================================
echo CLEAN
echo ========================================
if exist "%BUILD_DIR%" (
rmdir /s /q "%BUILD_DIR%"
)

echo.
echo ========================================
echo CONFIGURE
echo ========================================
%CMAKE% --preset Qt-Msvc-Debug

if errorlevel 1 (
echo.
echo CONFIGURE FAILED
pause
exit /b 1
)

echo.
echo ========================================
echo BUILD
echo ========================================
%CMAKE% --build "%BUILD_DIR%" --target MuseScoreStudio --config Debug

if errorlevel 1 (
echo.
echo BUILD FAILED
pause
exit /b 1
)

echo.
echo ========================================
echo INSTALL
echo ========================================
%CMAKE% --install "%BUILD_DIR%" --config Debug --prefix "%INSTALL_DIR%"

if errorlevel 1 (
echo.
echo INSTALL FAILED
pause
exit /b 1
)

echo.
echo ========================================
echo RUN
echo ========================================

if not exist "%INSTALL_DIR%\bin\MuseScoreStudio5.exe" (
echo.
echo ERROR:
echo MuseScoreStudio5.exe was not found at:
echo %INSTALL_DIR%\bin\MuseScoreStudio5.exe
echo.
echo Searching for executable...
dir /s /b "%BUILD_DIR%\MuseScoreStudio5.exe" 2>nul
dir /s /b "%BUILD_DIR%*.exe" 2>nul
pause
exit /b 1
)

start "" "%INSTALL_DIR%\bin\MuseScoreStudio5.exe"

endlocal
