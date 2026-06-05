@echo off
chcp 65001 >nul
title Proxy Ollama - BONI Backend
echo ========================================
echo  Proxy Ollama - BONI Backend
echo  Proxy ligero Ollama (reemplaza jarvis serve)
echo ========================================
echo.
echo Deteniendo proxy anterior (si existe)...
wsl -d Ubuntu-22.04 -- pkill -f ollama_proxy 2>nul
timeout /t 2 /nobreak >nul

echo Copiando proxy...\
wsl -d Ubuntu-22.04 -- bash -c "cp /mnt/c/Users/nosoy/OneDrive/Desktop/boni/ollama_proxy.py /root/ollama_proxy.py 2>/dev/null || echo 'Proxy ya existe en /root/'"

echo.
echo Iniciando proxy Ollama en WSL:8080...
echo (usa Ctrl+C para detener)
echo.
wsl -d Ubuntu-22.04 -- python3 /root/ollama_proxy.py
