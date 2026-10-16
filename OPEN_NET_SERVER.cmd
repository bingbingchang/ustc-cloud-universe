@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "campus\run_game.ps1" -Server
pause
