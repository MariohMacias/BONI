@echo off
chcp 65001 >nul
title BONI - Reparar OpenJarvis
color 0B
cls
echo ============================================
echo      BONI - Diagnostico OpenJarvis
echo ============================================
echo.

:: 1. Ollama?
echo [1] Ollama...
curl -s --connect-timeout 3 http://localhost:11434/api/tags >nul 2>&1
if %errorlevel% equ 0 (
    echo     OK - Ollama corriendo en localhost:11434
    echo.
    echo     Modelos disponibles:
    curl -s http://localhost:11434/api/tags | python -c "import sys,json;d=json.load(sys.stdin);[print('     - '+m['name']) for m in d.get('models',[])]" 2>nul
) else (
    echo     ERR - Ollama no responde
    echo     ^> Ejecuta: ollama serve (en otra terminal)
)
echo.

:: 2. WSL IP
echo [2] WSL IP...
for /f "usebackq" %%i in (`wsl -d Ubuntu-22.04 bash -c "hostname -I | cut -d' ' -f1" 2^>nul`) do set WSL_IP=%%i
if defined WSL_IP (
    echo     OK - WSL IP: %WSL_IP%
) else (
    echo     ERR - No se pudo detectar WSL
)
echo.

:: 3. OpenJarvis Server en WSL
echo [3] OpenJarvis Server (WSL:8000)...
wsl -d Ubuntu-22.04 bash -c "curl -s --connect-timeout 3 http://127.0.0.1:8000/health 2>/dev/null" >nul 2>&1
if %errorlevel% equ 0 (
    echo     OK - OpenJarvis Server respondiendo
) else (
    echo     ERR - No responde. Iniciando...
    wsl -d Ubuntu-22.04 bash -c "source ~/.bashrc 2>/dev/null; mkdir -p ~/.boni; nohup jarvis start > ~/.boni/jarvis.log 2>&1 &"
    echo     Esperando 8 segundos...
    timeout /t 8 /nobreak >nul
    wsl -d Ubuntu-22.04 bash -c "curl -s --connect-timeout 3 http://127.0.0.1:8000/health 2>/dev/null" >nul 2>&1
    if %errorlevel% equ 0 (
        echo     OK - Ahora responde
    ) else (
        echo     ERR - Sigue sin responder. Revisa WSL manualmente
    )
)
echo.

:: 4. Config OpenJarvis Desktop
echo [4] Config OpenJarvis Desktop...
if exist "%USERPROFILE%\.openjarvis\config.toml" (
    echo     OK - Config encontrado
    type "%USERPROFILE%\.openjarvis\config.toml"
) else (
    echo     ERR - No existe config
)
echo.

:: 5. Test modelo directo
echo [5] Test boni-rapido:latest (puede tardar ~60s la primera vez)...
echo     Enviando ping al modelo...
curl -s --connect-timeout 10 --max-time 70 -X POST http://localhost:11434/api/generate ^
  -H "Content-Type: application/json" ^
  -d "{\"model\":\"boni-rapido:latest\",\"prompt\":\"Di solo OK en una palabra\",\"stream\":false,\"options\":{\"num_ctx\":1024,\"num_predict\":20}}" ^
  > "%TEMP%\boni_test.json" 2>nul
if %errorlevel% equ 0 (
    python -c "import json;d=json.load(open(r'%TEMP%\boni_test.json'));print('     OK - Modelo responde:', d.get('response','?')[:50])" 2>nul
) else (
    echo     ERR - Modelo no responde (puede ser timeout por carga fria)
)
echo.
echo ============================================
echo Si algo fallo:
echo 1. Abre PowerShell como ADMIN y corre:
echo    wsl -d Ubuntu-22.04
echo    jarvis stop ^&^& jarvis start
echo    curl http://127.0.0.1:8000/health
echo.
echo 2. Si el modelo no responde, prueba con turbo:
echo    curl -X POST http://localhost:11434/api/generate -d "{\"model\":\"qwen3.5:2b\",\"prompt\":\"hola\"}"
echo ============================================
pause
