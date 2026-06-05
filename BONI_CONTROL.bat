@echo off
chcp 65001 >nul
title BONI v2.1 - Control Center
setlocal enabledelayedexpansion

:: =====================================================
:: BONI v2.1 - Inicio Unificado
:: Detecta IPs, inicia servicios, abre ambos frontends
:: =====================================================

:MENU
cls
color 0A
echo.
echo  ╔══════════════════════════════════════╗
echo  ║       BONI v2.1 - Control Center     ║
echo  ║   OpenJarvis + Ollama + WebUI x2     ║
echo  ╚══════════════════════════════════════╝
echo.
echo   [1] Iniciar TODO
echo   [2] Detener TODO  
echo   [3] Abrir Web UIs
echo   [4] Ver estado
echo   [5] Reparar Docker (reinstalar)
echo   [6] Salir
echo.
set /p OPC="Elige: "
if "%OPC%"=="1" goto INICIAR
if "%OPC%"=="2" goto DETENER
if "%OPC%"=="3" goto ABRIR
if "%OPC%"=="4" goto ESTADO
if "%OPC%"=="5" goto REPARAR_DOCKER
if "%OPC%"=="6" exit
goto MENU

:INICIAR
cls
echo.
echo ============================================
echo  Iniciando BONI v2.1
echo ============================================
echo.

:: Detectar IP de WSL
echo [*] Detectando IPs...
for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 -- bash -c "hostname -I | awk '{print $1}'" 2^>nul') do set WSL_IP=%%i
for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 -- bash -c "ip route ^| grep default ^| awk '{print $3}'" 2^>nul') do set WIN_GW=%%i

if "%WSL_IP%"=="" (
    echo [!] WSL no responde, iniciando...
    wsl -d Ubuntu-22.04 bash -c "echo ready" >nul 2>&1
    timeout /t 8 >nul
    for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 -- bash -c "hostname -I ^| awk '{print $1}'" 2^>nul') do set WSL_IP=%%i
    for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 -- bash -c "ip route ^| grep default ^| awk '{print $3}'" 2^>nul') do set WIN_GW=%%i
)

echo    WSL IP:     !WSL_IP!
echo    Windows GW: !WIN_GW!

:: Guardar .env
(echo WSL_IP=!WSL_IP!&echo WIN_GW=!WIN_GW!&echo JARVIS_API=http://!WSL_IP!:8080/v1&echo JARVIS_KEY=boni-local-key&echo OLLAMA_URL=http://localhost:11434) >"%USERPROFILE%\OneDrive\Desktop\boni\.env" 2>nul

:: 1. OLLAMA
echo.
echo [1/4] Ollama...
tasklist /FI "IMAGENAME eq ollama.exe" 2>nul | find /I "ollama.exe" >nul
if !ERRORLEVEL! EQU 0 (echo    [OK] Ya corriendo) else (
    echo    Iniciando...
    start /B "" "ollama" serve
    timeout /t 4 >nul
    curl.exe -s --max-time 5 http://localhost:11434/api/tags >nul 2>&1
    if !ERRORLEVEL! EQU 0 (echo    [OK]) else (echo    [WARN] No responde)
)

:: 2. JARVIS SERVE
echo.
echo [2/4] jarvis serve...
wsl -d Ubuntu-22.04 -- bash -c "curl -s http://localhost:8080/health 2>/dev/null" | find "ok" >nul
if !ERRORLEVEL! EQU 0 (echo    [OK] Ya corriendo) else (
    echo    Iniciando...
    wsl -d Ubuntu-22.04 -- bash -c "jarvis config set engine.ollama.host http://!WIN_GW!:11434 >/dev/null 2>&1"
    wsl -d Ubuntu-22.04 -- bash -c "mkdir -p ~/.boni && export OPENJARVIS_API_KEY=boni-local-key && setsid jarvis serve --host 0.0.0.0 --port 8080 -e ollama -m boni-rapido:latest > ~/.boni/jarvis.log 2>&1 & disown"
    timeout /t 10 >nul
    curl.exe -s --max-time 5 "http://!WSL_IP!:8080/health" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (echo    [OK] Puerto 8080) else (echo    [WARN] No responde)
)

:: 3. OPEN WEBUI (Docker)
echo.
echo [3/4] Open WebUI...
docker ps --filter name=open-webui --format "{{.Status}}" 2>nul | find "Up" >nul
if !ERRORLEVEL! EQU 0 (echo    [OK] Corriendo en http://localhost:3000) else (
    docker start open-webui 2>nul
    if !ERRORLEVEL! EQU 0 (echo    [OK] Iniciado) else (echo    [--] Docker no disponible)
)

:: 4. BONI WEB UI (Flask)
echo.
echo [4/4] BONI Web UI...
tasklist /FI "IMAGENAME eq python.exe" 2>nul | findstr /C:"boni_webui" >nul 2>&1
if !ERRORLEVEL! EQU 0 (echo    [OK] Ya corriendo) else (
    set JARVIS_URL=http://!WSL_IP!:8080
    set JARVIS_KEY=boni-local-key
    set PORT=3001
    start /B "" "C:\Users\nosoy\AppData\Local\Programs\Python\Python312\python.exe" "%USERPROFILE%\OneDrive\Desktop\boni\boni_webui.py"
    timeout /t 5 >nul
    curl.exe -s --max-time 5 http://localhost:3001/ >nul 2>&1
    if !ERRORLEVEL! EQU 0 (echo    [OK] Web UI en localhost:3001) else (echo    [WARN] No responde)
)

:: Abrir navegadores
timeout /t 2 >nul
echo.
echo ============================================
echo  TODO INICIADO
echo ============================================
echo  Ollama:        http://localhost:11434
echo  jarvis serve:  http://!WSL_IP!:8080/v1
echo  BONI Web UI:   http://localhost:3001
echo  Open WebUI:    http://localhost:3000 (si Docker corre)
echo.
start http://localhost:3001
start http://localhost:3000
echo  Presiona cualquier tecla para ir al menu
pause >nul
goto MENU

:DETENER
cls
echo.
echo Deteniendo...
taskkill /F /IM python.exe 2>nul
wsl -d Ubuntu-22.04 -- bash -c "pkill -f 'jarvis serve' 2>/dev/null"
docker stop open-webui 2>nul
echo  [OK] Sistema detenido
pause
goto MENU

:ABRIR
start http://localhost:3001
start http://localhost:3000
goto MENU

:ESTADO
cls
echo.
echo ============================================
echo  Estado del sistema
echo ============================================
echo.
set OLLAMA=NO
set JARVIS=NO
set WEBUI=NO
set DOCKER=NO

curl.exe -s --max-time 3 http://localhost:11434/api/tags >nul 2>&1 && set OLLAMA=SI
for /f "tokens=*" %%i in ('wsl -d Ubuntu-22.04 -- bash -c "hostname -I 2>/dev/null"') do set WSL_IP=%%i
curl.exe -s --max-time 3 "http://!WSL_IP!:8080/health" >nul 2>&1 && set JARVIS=SI
curl.exe -s --max-time 3 http://localhost:3001/ >nul 2>&1 && set WEBUI=SI
curl.exe -s --max-time 3 http://localhost:3000/ >nul 2>&1 && set DOCKER=SI

echo    Ollama:      !OLLAMA!
echo    jarvis:      !JARVIS!
echo    Web UI:      !WEBUI!
echo    Open WebUI:  !DOCKER!
echo.
pause
goto MENU

:REPARAR_DOCKER
cls
echo.
echo ============================================
echo  REPARAR DOCKER DESKTOP
echo ============================================
echo.
echo  Esto descargara ~617MB e instalara Docker
echo  Desktop limpio.
echo.
echo  PASOS (ejecutar en PowerShell Admin):
echo.
echo  1. Stop-Process -Name "Docker Desktop" -Force
echo  2. Remove-Item \"$env:APPDATA\Docker\" -Recurse -Force
echo  3. Remove-Item \"$env:LOCALAPPDATA\Docker\" -Recurse -Force
echo  4. winget install Docker.DockerDesktop --silent
echo  5. Iniciar Docker Desktop y esperar
echo  6. docker run -d --name open-webui -p 3000:8080...
echo.
echo  O abre PowerShell Admin y pega:
echo.
echo  winget install Docker.DockerDesktop ^
echo    --silent --accept-package-agreements
echo.
pause
goto MENU
