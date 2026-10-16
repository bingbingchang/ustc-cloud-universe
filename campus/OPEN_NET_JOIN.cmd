@echo off
set /p HOSTIP=输入主机局域网 IP（例如 192.168.1.5，直接回车则连本机）:
if "%HOSTIP%"=="" set HOSTIP=127.0.0.1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_game.ps1" -NetJoin "%HOSTIP%"
