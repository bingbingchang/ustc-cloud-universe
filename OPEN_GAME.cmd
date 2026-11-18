@echo off
setlocal
cd /d "%~dp0"
if not defined GODOT_EXE if exist "E:\Tools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe" set "GODOT_EXE=E:\Tools\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File "campus\run_game.ps1"
pause
endlocal
