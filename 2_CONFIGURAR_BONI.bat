@echo off
chcp 65001 >nul
title BONI - Configurador

color 0B
echo.
echo  [BONI] Configurando personalidad y herramientas...
echo.

REM ── Esperar a que Open WebUI esté listo ──────────────────────
echo  Verificando que Open WebUI esté activo...
:CHECK_WEBUI
curl -s http://localhost:3000 >nul 2>&1
if %errorlevel% neq 0 (
    echo  Esperando Open WebUI...
    timeout /t 5 >nul
    goto CHECK_WEBUI
)
echo  [OK] Open WebUI activo.
echo.

REM ── Verificar Ollama ─────────────────────────────────────────
echo  Verificando que Ollama esté activo...
curl -s http://localhost:11434/api/tags >nul 2>&1
if %errorlevel% neq 0 (
    echo  Iniciando Ollama...
    start /B ollama serve
    timeout /t 5 >nul
)
echo  [OK] Ollama activo.
echo.

echo  ════════════════════════════════════════
echo   Configuración completada en navegador
echo  ════════════════════════════════════════
echo.
echo  Abre http://localhost:3000 y sigue estas instrucciones:
echo.
echo  PASO A - System Prompt de BONI:
echo  ─────────────────────────────────
echo  1. Ve a Settings ^> Workspace ^> Models
echo  2. Edita "qwen2.5:7b"
echo  3. En "System Prompt" pega el contenido de:
echo         BONI_system_prompt.txt
echo.
echo  PASO B - Crear Workspace "BONI":
echo  ─────────────────────────────────
echo  1. En la barra lateral, crea un nuevo Chat
echo  2. Selecciona el modelo qwen2.5:7b
echo  3. ¡BONI está listo para conversar!
echo.
echo  PASO C - Activar herramientas (opcional, avanzado):
echo  ─────────────────────────────────────────────────────
echo  1. Ve a Settings ^> Tools
echo  2. Importa los archivos de BONI_tools/
echo.

REM Abrir el panel y el archivo de system prompt
start http://localhost:3000
start notepad "BONI_system_prompt.txt"

echo  [OK] Abriendo panel y system prompt...
pause
