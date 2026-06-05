@echo off
chcp 65001 >nul
title BONI - Reparación automática
color 0B

echo.
echo  ██████╗  ██████╗ ███╗   ██╗██╗
echo  ██╔══██╗██╔═══██╗████╗  ██║██║
echo  ██████╔╝██║   ██║██╔██╗ ██║██║
echo  ██╔══██╗██║   ██║██║╚██╗██║██║
echo  ██████╔╝╚██████╔╝██║ ╚████║██║
echo  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝
echo  REPARACIÓN AUTOMÁTICA v1.0
echo.

echo [1/5] Verificando Docker...
docker ps --filter name=open-webui --format "open-webui: {{.Status}}" 2>nul
if %errorlevel% neq 0 (
    echo [!] Docker no responde. Abre Docker Desktop.
    pause
    exit /b
)

echo [2/5] Verificando Ollama...
ollama list 2>nul | find "qwen2.5:7b" >nul
if %errorlevel% neq 0 (
    echo [!] qwen2.5:7b no encontrado. Descargando...
    ollama pull qwen2.5:7b
) else (
    echo [OK] qwen2.5:7b instalado
)

echo [3/5] Recreando contenedor Open WebUI (para limpiar bug)...
docker stop open-webui >nul 2>&1
docker rm open-webui >nul 2>&1
echo      Descargando última versión y levantando...
docker run -d --name open-webui -p 3000:8080 -v open-webui:/app/backend/data --add-host=host.docker.internal:host-gateway -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -e WEBUI_NAME="BONI AI" -e WEBUI_SECRET_KEY="boni-mario-secret-2024" --restart always ghcr.io/open-webui/open-webui:main

echo      Esperando 45 segundos...
timeout /t 45 /nobreak >nul

echo [4/5] Ejecutando configuración automática...
set PYTHONIOENCODING=utf-8
where python >nul 2>&1
if %errorlevel% neq 0 (
    where py >nul 2>&1
    if %errorlevel% neq 0 (
        echo [!] Python no encontrado. Abre http://localhost:3000 manualmente.
        start http://localhost:3000
        pause
        exit /b
    )
)

cd /d "%~dp0"
python fix_boni.py 2>&1

echo [5/5] Abriendo BONI en el navegador...
start http://localhost:3000

echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║   ✓  Reparación completada                       ║
echo  ║                                                  ║
echo  ║   Panel:  http://localhost:3000                  ║
echo  ║   Email:  mario@boni.local                       ║
echo  ║   Pass:   boni2024mario                          ║
echo  ╚══════════════════════════════════════════════════╝
echo.
pause
