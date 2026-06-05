@echo off
chcp 65001 >nul
title BONI v2.1
color 0B
echo.
echo  ██████╗  ██████╗ ███╗   ██╗██╗
echo  ██╔══██╗██╔═══██╗████╗  ██║██║
echo  ██████╔╝██║   ██║██╔██╗ ██║██║
echo  ██╔══██╗██║   ██║██║╚██╗██║██║
echo  ██████╔╝╚██████╔╝██║ ╚████║██║
echo  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝
echo  v2.1 — Stack completo
echo.
echo  Iniciando BONI...
powershell -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File ""%~dp0boni\BONI_INICIO.ps1""' -Verb RunAs -Wait"
pause
