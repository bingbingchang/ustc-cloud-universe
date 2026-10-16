@echo off
rem Host WITHOUT a window and WITHOUT GPU work. Use this on the machine that
rem acts as the server, then open one normal client via OPEN_NET_JOIN.cmd.
rem Two graphical instances on one machine can lose their Vulkan surface.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_game.ps1" -Server
