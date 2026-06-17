@echo off
chcp 65001 >nul
title BONI v2.1 - Inicio Automatico
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INICIO_AUTOMATICO.ps1"
pause
