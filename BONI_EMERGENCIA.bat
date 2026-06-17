@echo off
chcp 65001 >nul
title BONI v2.1 - Reinicio de Emergencia
setlocal enabledelayedexpansion
cls

echo ============================================================
echo   BONI v2.1 - Reinicio Rapido de Servicios WSL
echo ============================================================
echo   Arquitectura: Ollama en Windows, servicios en WSL
echo ============================================================
echo.

rem --- Verificar que Windows services estan arriba ---
echo [Sondeo] Servicios Windows...
curl -s --connect-timeout 3 http://localhost:11434/api/tags >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] Ollama Windows :11434) else (echo   [WARN] Ollama Windows no responde - ejecuta 'ollama serve')
curl -s --connect-timeout 3 http://localhost:8765/ >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] Sandbox :8765) else (echo   [WARN] Sandbox caido)
curl -s --connect-timeout 3 http://localhost:8080/ >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] Proxy :8080) else (echo   [WARN] Proxy caido)
echo.

rem --- Detectar gateway de WSL hacia Windows ---
echo [1/4] Detectando gateway WSL...
for /f "usebackq" %%i in (`wsl -d Ubuntu-22.04 -- bash -lc "ip route | grep default | awk '{print \$3}'" 2^>nul`) do set WIN_GW=%%i
if defined WIN_GW (
    echo   [OK] Gateway: %WIN_GW%
) else (
    set WIN_GW=172.29.176.1
    echo   [WARN] Usando fallback: 172.29.176.1
)
echo.

rem --- Configurar IP de Ollama en OpenJarvis ---
echo [2/4] Configurando IP de Ollama en config.toml...
wsl -d Ubuntu-22.04 -- bash -lc "source ~/.bashrc 2>/dev/null; jarvis config set engine.ollama.host http://%WIN_GW%:11434; jarvis config set engine.ollama.url http://%WIN_GW%:11434" >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] Config actualizada con IP %WIN_GW%) else (echo   [WARN] No se pudo actualizar config)
echo.

rem --- Reiniciar OpenJarvis Server ---
echo [3/4] Reiniciando OpenJarvis Server...
wsl -d Ubuntu-22.04 -- bash -lc "pkill -f 'openjarvis.cli' 2>/dev/null; pkill -f 'jarvis serve' 2>/dev/null; sleep 2; rm -f ~/.boni/jarvis2.log; source ~/.bashrc; mkdir -p ~/.boni; nohup python3.10 -m openjarvis.cli serve --port 8000 > ~/.boni/jarvis2.log 2>&1 &"
echo   Esperando cold import (~40s)...
set JARVIS_READY=0
for /l %%i in (1,1,12) do (
    timeout /t 10 /nobreak >nul
    wsl -d Ubuntu-22.04 -- bash -lc "curl -sf --connect-timeout 3 http://127.0.0.1:8000/health >/dev/null 2>&1"
    if !errorlevel! equ 0 (
        echo   [OK] OpenJarvis responde en WSL:8000 (tras %%i*10s)
        set JARVIS_READY=1
        goto :jarvis_done
    )
    if %%i equ 3 (echo   Aun importando... (30s))
    if %%i equ 6 (echo   Sigue importando... (60s — carga fria ~36s+))
)
:jarvis_done
if !JARVIS_READY! equ 0 echo   [WARN] OpenJarvis no respondio tras 120s. Revisa: wsl tail -20 ~/.boni/jarvis2.log
echo.

rem --- Verificar TTS ---
echo [4/4] Verificando TTS...
wsl -d Ubuntu-22.04 -- bash -lc "curl -sf --connect-timeout 3 http://localhost:5050/health >/dev/null 2>&1"
if %errorlevel% equ 0 (echo   [OK] TTS Server responde en WSL:5050) else (echo   [WARN] TTS caido - ejecuta BONI_INICIO.ps1 o instala espeak-ng)
echo.

rem --- Verificacion final ---
echo ============================================================
echo   Verificacion final
echo ============================================================
wsl -d Ubuntu-22.04 -- bash -lc "
    echo -n 'OpenJarvis  : '; curl -sf --connect-timeout 3 http://127.0.0.1:8000/health >/dev/null 2>&1 && echo 'OK' || echo 'FAIL';
    echo -n 'TTS         : '; curl -sf --connect-timeout 3 http://127.0.0.1:5050/health >/dev/null 2>&1 && echo 'OK' || echo 'FAIL';
    echo -n 'Config host : '; grep -E 'host|url' ~/.openjarvis/config.toml 2>/dev/null || echo 'no config';
    echo -n 'Gateway     : '; ip route | grep default | awk '{print \$3}' 2>/dev/null || echo unknown;
"

echo.
echo  Servicios WSL reiniciados. Proxy en http://localhost:8080
echo.
pause
