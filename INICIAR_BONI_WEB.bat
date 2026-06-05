@echo off
chcp 65001 >nul
title BONI - Sistema Completo
setlocal enabledelayedexpansion

:: =====================================================
:: BONI + OpenJarvis - Inicio Completo
:: Detecta IPs, inicia servicios, actualiza config
:: =====================================================

:INIT
cls
color 0A
echo ============================================
echo    BONI v2.1 - Sistema Completo
echo    OpenJarvis + Ollama + WebUI
echo ============================================
echo.
echo [*] Detectando entorno...
echo.

:: --- Detectar IPs ---
for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 hostname -I 2^>nul') do set "WSL_IP=%%i"
for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 bash -c "ip route ^| grep default ^| awk '{print $3}'" 2^>nul') do set "WIN_GW=%%i"

if "%WSL_IP%"=="" (
    echo [!] WSL no detectado. Iniciando...
    wsl -d Ubuntu-22.04 bash -c "echo ready"
    timeout /t 5 >nul
    for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 hostname -I 2^>nul') do set "WSL_IP=%%i"
    for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 bash -c "ip route ^| grep default ^| awk '{print $3}'" 2^>nul') do set "WIN_GW=%%i"
)

set WSL_IP=%WSL_IP: =%
echo    WSL IP:       %WSL_IP%
echo    Windows GW:   %WIN_GW%

:: --- Guardar .env ---
(
echo WSL_IP=%WSL_IP%
echo WIN_GW=%WIN_GW%
echo JARVIS_API=http://%WSL_IP%:8080/v1
echo JARVIS_KEY=boni-local-key
echo OLLAMA_URL=http://localhost:11434
) > "%USERPROFILE%\OneDrive\Desktop\boni\.env" 2>nul

:: =====================================================
:: 1. OLLAMA
:: =====================================================
echo.
echo [1/4] Ollama...
tasklist /FI "IMAGENAME eq ollama.exe" 2>nul | find /I "ollama.exe" >nul
if !ERRORLEVEL! EQU 0 (
    echo    [OK] Ya corriendo
) else (
    echo    Iniciando...
    start /B "" "ollama" serve
    timeout /t 3 >nul
    curl.exe -s --max-time 5 http://localhost:11434/api/tags >nul 2>&1
    if !ERRORLEVEL! EQU 0 (echo    [OK]) else (echo    [WARN] No responde aun)
)

:: =====================================================
:: 2. JARVIS SERVE
:: =====================================================
echo.
echo [2/4] jarvis serve (OpenJarvis API)...

:: Verificar si ya corre
wsl -d Ubuntu-22.04 bash -c "ps aux | grep 'jarvis serve' | grep -v grep" 2>nul | find "jarvis" >nul
if !ERRORLEVEL! EQU 0 (
    echo    [OK] Ya corriendo
) else (
    echo    Iniciando en WSL...
    wsl -d Ubuntu-22.04 bash -c "jarvis config set engine.ollama.host http://%WIN_GW%:11434 >/dev/null 2>&1"
    wsl -d Ubuntu-22.04 bash -c "export OPENJARVIS_API_KEY=boni-local-key; setsid jarvis serve --host 0.0.0.0 --port 8080 -e ollama -m boni-rapido:latest > /tmp/jarvis-serve.log 2>&1 & disown"
    timeout /t 8 >nul
    curl.exe -s --max-time 5 "http://%WSL_IP%:8080/health" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (echo    [OK] Puerto 8080) else (echo    [WARN] No responde aun)
)

:: =====================================================
:: 3. OPEN WEBUI (Docker)
:: =====================================================
echo.
echo [3/4] Open WebUI (Docker)...
docker ps --filter name=open-webui --format "{{.Status}}" 2>nul | find "Up" >nul
if !ERRORLEVEL! EQU 0 (
    echo    [OK] Corriendo en http://localhost:3000
) else (
    echo    Intentando arrancar...
    docker start open-webui 2>nul
    if !ERRORLEVEL! NEQ 0 (
        echo    [SKIP] Docker no disponible. Instalacion manual requerida.
        echo    Para instalar: corre '3_INICIAR_BONI.bat' opcion 5
    ) else (
        timeout /t 5 >nul
        echo    [OK] Open WebUI en http://localhost:3000
    )
)

:: =====================================================
:: 4. WEB UI (Flask)
:: =====================================================
echo.
echo [4/4] BONI Web UI (Flask)...

:: Matar instancia anterior si existe
for /f "tokens=2 delims=," %%a in ('tasklist /FI "IMAGENAME eq python.exe" /FO CSV /NH 2^>nul ^| findstr "boni_webui"') do (
    taskkill /F /PID %%a >nul 2>&1
)

set JARVIS_URL=http://%WSL_IP%:8080
set JARVIS_KEY=boni-local-key
set PORT=3001

start /B "" "C:\Users\nosoy\AppData\Local\Programs\Python\Python312\python.exe" "%USERPROFILE%\OneDrive\Desktop\boni\boni_webui.py"

timeout /t 4 >nul
curl.exe -s --max-time 5 http://localhost:3001/ >nul 2>&1
if !ERRORLEVEL! EQU 0 (echo    [OK] Web UI en http://localhost:3001) else (echo    [WARN] Web UI no responde aun)

:: =====================================================
:: MOSTRAR ESTADO
:: =====================================================
echo.
echo ============================================
echo  TODO INICIADO
echo ============================================
echo.
echo  Ollama:        http://localhost:11434
echo  jarvis serve:  http://%WSL_IP%:8080/v1
echo  BONI Web UI:   http://localhost:3001
echo  Open WebUI:    http://localhost:3000 (si Docker corre)
echo.
echo  Config:        %USERPROFILE%\OneDrive\Desktop\boni\.env
echo.
echo  Abriendo BONI Web UI...
start http://localhost:3001

:: Verificar estado continuo
echo.
echo  Verificando componentes...
ping -n 1 localhost >nul

set OLLAMA_OK=NO
set JARVIS_OK=NO
set WEBUI_OK=NO

curl.exe -s --max-time 3 http://localhost:11434/api/tags >nul 2>&1 && set OLLAMA_OK=SI
curl.exe -s --max-time 3 "http://%WSL_IP%:8080/health" >nul 2>&1 && set JARVIS_OK=SI
curl.exe -s --max-time 3 http://localhost:3001/ >nul 2>&1 && set WEBUI_OK=SI

echo.
echo  Estado:
echo    Ollama:      !OLLAMA_OK!
echo    jarvis:      !JARVIS_OK!
echo    Web UI:      !WEBUI_OK!
echo.
echo  Presiona cualquier tecla para DETENER todo
pause >nul

:: =====================================================
:: DETENER
:: =====================================================
:DETENER
cls
echo.
echo Deteniendo servicios...
echo.
taskkill /F /IM python.exe 2>nul && echo  [OK] Web UI detenido
wsl -d Ubuntu-22.04 bash -c "pkill -f 'jarvis serve' 2>/dev/null" 2>nul && echo  [OK] jarvis serve detenido
docker stop open-webui 2>nul && echo  [OK] Open WebUI detenido
echo.
echo  Sistema detenido.
timeout /t 3 >nul
goto :EOF
