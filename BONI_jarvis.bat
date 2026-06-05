@echo off
title BONI - OpenJarvis
echo ====================================
echo Iniciando BONI v2.1 (OpenJarvis)
echo ====================================
echo.
echo Engine: Ollama (boni-rapido:latest / qwen2.5:3b)
echo Chat: %USERPROFILE%\.openjarvis\config.toml
echo.
wsl -d Ubuntu-22.04 bash -c "jarvis chat -e ollama -m boni-rapido:latest" 2>&1
echo.
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] OpenJarvis no pudo iniciar.
    echo Prueba: abre cmd y ejecuta: wsl -d Ubuntu-22.04
    pause
)
