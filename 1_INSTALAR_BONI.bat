@echo off
chcp 65001 >nul
title BONI - Instalador Automático

REM ============================================================
REM  B.O.N.I. - Instalador Automático para Windows 10
REM  Instala: Ollama + modelo qwen2.5:7b + Open WebUI (Docker)
REM  100%% local, 100%% gratis, sin suscripciones
REM ============================================================

color 0A
echo.
echo  ██████╗  ██████╗ ███╗   ██╗██╗
echo  ██╔══██╗██╔═══██╗████╗  ██║██║
echo  ██████╔╝██║   ██║██╔██╗ ██║██║
echo  ██╔══██╗██║   ██║██║╚██╗██║██║
echo  ██████╔╝╚██████╔╝██║ ╚████║██║
echo  ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝
echo.
echo  Business Operations Neural Intelligence
echo  ─────────────────────────────────────────
echo  Instalador v1.0  ^|  100%% Local ^| 100%% Gratis
echo.
pause

REM ── PASO 1: Verificar Docker ──────────────────────────────────
echo.
echo [1/4] Verificando Docker Desktop...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [!] Docker Desktop no encontrado.
    echo      Por favor instálalo desde:
    echo      https://www.docker.com/products/docker-desktop/
    echo.
    echo      Luego vuelve a ejecutar este script.
    pause
    start https://www.docker.com/products/docker-desktop/
    exit /b 1
)
echo  [OK] Docker encontrado.

REM ── PASO 2: Verificar/Instalar Ollama ────────────────────────
echo.
echo [2/4] Verificando Ollama...
ollama --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Ollama no encontrado. Descargando instalador...
    curl -L -o "%TEMP%\OllamaSetup.exe" "https://ollama.com/download/OllamaSetup.exe"
    if %errorlevel% neq 0 (
        echo  [ERROR] No se pudo descargar Ollama. Verifica tu conexión.
        pause
        exit /b 1
    )
    echo  Instalando Ollama...
    start /wait "" "%TEMP%\OllamaSetup.exe" /S
    timeout /t 5 >nul
    REM Agregar Ollama al PATH de esta sesión
    set PATH=%PATH%;%LOCALAPPDATA%\Programs\Ollama
)
echo  [OK] Ollama listo.

REM ── PASO 3: Descargar modelo qwen2.5:7b ──────────────────────
echo.
echo [3/4] Descargando modelo de lenguaje qwen2.5:7b...
echo       (Primera vez: ~4.7 GB. Puede tardar varios minutos)
echo       Esto es el "cerebro" de BONI — corre 100%% local.
echo.
ollama pull qwen2.5:7b
if %errorlevel% neq 0 (
    echo  [ERROR] No se pudo descargar el modelo.
    echo          Verifica tu conexión a internet e intenta de nuevo.
    pause
    exit /b 1
)
echo  [OK] Modelo descargado.

REM ── PASO 4: Instalar Open WebUI con Docker ───────────────────
echo.
echo [4/4] Instalando Open WebUI (panel de BONI)...
echo       Puerto: http://localhost:3000

REM Detener contenedor anterior si existe
docker stop open-webui >nul 2>&1
docker rm open-webui >nul 2>&1

REM Levantar Open WebUI conectado a Ollama local
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

if %errorlevel% neq 0 (
    echo  [ERROR] No se pudo iniciar Open WebUI.
    echo          Asegúrate de que Docker Desktop esté corriendo.
    pause
    exit /b 1
)

echo.
echo  Esperando que Open WebUI inicie (30 segundos)...
timeout /t 30 >nul

REM ── FINALIZADO ───────────────────────────────────────────────
color 0B
echo.
echo  ╔══════════════════════════════════════════╗
echo  ║   ✓  BONI instalado correctamente        ║
echo  ║                                          ║
echo  ║   Panel:   http://localhost:3000         ║
echo  ║   Modelo:  qwen2.5:7b (local)            ║
echo  ║   Estado:  corriendo en segundo plano    ║
echo  ╚══════════════════════════════════════════╝
echo.
echo  PRÓXIMOS PASOS:
echo  1. Abre http://localhost:3000 en tu navegador
echo  2. Crea tu cuenta (la primera = administrador)
echo  3. Ejecuta "2_CONFIGURAR_BONI.bat" para personalizar
echo.
start http://localhost:3000
pause
