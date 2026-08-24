
cd /d C:\Users\dadmehr\Desktop\MuseScore_BK\MuseScore

echo Building...
cmake --build build\Qt-Msvc-Debug --target MuseScoreStudio --config Debug

echo Installing...
cmake --install build\Qt-Msvc-Debug --config Debug

echo Running...
start "" "C:\Users\dadmehr\Desktop\MuseScore_BK\MuseScore\build\Qt-Msvc-Debug\install\bin\MuseScoreStudio5.exe"