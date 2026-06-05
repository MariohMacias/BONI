@echo off
chcp 65001 >nul
title BONI - Control

:MENU
cls
color 0A
echo.
echo  ╔═══════════════════════════════╗
echo  ║        BONI - Control         ║
echo  ╚═══════════════════════════════╝
echo.
echo   [1] Iniciar BONI
echo   [2] Detener BONI
echo   [3] Abrir panel (localhost:3000)
echo   [4] Ver estado
echo   [5] Actualizar BONI (pull imagen)
echo   [6] Salir
echo.
set /p OPC="Elige una opción: "

if "%OPC%"=="1" goto INICIAR
if "%OPC%"=="2" goto DETENER
if "%OPC%"=="3" goto ABRIR
if "%OPC%"=="4" goto ESTADO
if "%OPC%"=="5" goto ACTUALIZAR
if "%OPC%"=="6" exit

:INICIAR
echo.
echo  Iniciando Ollama...
start /B ollama serve
timeout /t 3 >nul
echo  Iniciando Open WebUI...
docker start open-webui
timeout /t 10 >nul
echo  [OK] BONI iniciado en http://localhost:3000
start http://localhost:3000
pause
goto MENU

:DETENER
echo.
docker stop open-webui
echo  [OK] BONI detenido.
pause
goto MENU

:ABRIR
start http://localhost:3000
goto MENU

:ESTADO
echo.
echo  ── Ollama ──────────────────────
ollama list
echo.
echo  ── Docker (Open WebUI) ─────────
docker ps --filter name=open-webui --format "  Estado: {{.Status}}"
echo.
pause
goto MENU

:ACTUALIZAR
echo.
echo  Actualizando imagen de Open WebUI...
docker pull ghcr.io/open-webui/open-webui:main
docker stop open-webui
docker rm open-webui
docker run -d ^
    --name open-webui ^
    -p 3000:8080 ^
    -v open-webui:/app/backend/data ^
    --add-host=host.docker.internal:host-gateway ^
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 ^
    -e WEBUI_NAME="BONI AI" ^
    -e WEBUI_SECRET_KEY="boni-mario-secret-2024" ^
    --restart always ^
    ghcr.io/open-webui/open-webui:main
echo  [OK] BONI actualizado.
pause
goto MENU
