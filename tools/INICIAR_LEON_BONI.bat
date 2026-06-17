@echo off
title Leon BONI v2.2 (GPU)
echo ========================================
echo   Iniciando Leon con personalidad BONI
echo   GPU: Qwen2.5 1.5B via Vulkan (fallback)
echo ========================================
echo.

echo [1/5] Iniciando servidor GPU (llama.cpp)...
start "llama.cpp GPU" cmd /c "C:\Users\nosoy\OneDrive\Desktop\INICIAR_LLAMACPP_SERVER.bat"
timeout /t 35 /nobreak >nul
netstat -ano | findstr ":8080 " >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] GPU server no responde en puerto 8080
    echo     Continuando igual - se usara solo OpenRouter
) else (
    echo [OK] GPU server listo en puerto 8080
)

echo [2/5] Verificando puerto 5366...
netstat -ano | findstr ":5366 " >nul 2>&1
if %errorlevel% equ 0 (
    echo [!] Puerto 5366 en uso. Matando proceso anterior...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5366 "') do (
        taskkill /f /pid %%a >nul 2>&1
    )
    timeout /t 2 /nobreak >nul
)

echo [3/5] Iniciando Leon...
cd /d "C:\Users\nosoy\OneDrive\Desktop\LEON_BONI"
set LEON_SERVER_NODE_PATH=C:\Users\nosoy\.leon\bin\node\node.exe
start "Leon BONI" cmd /c "pnpm start & pause"

echo [4/5] Iniciando watchdog...
start /min powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Users\nosoy\OneDrive\Desktop\LEON_WATCHDOG.ps1"

echo [5/5] Esperando servidor web...
timeout /t 20 /nobreak >nul
start http://localhost:5366

echo ========================================
echo   Leon corriendo en http://localhost:5366
echo   Modelo: Nemotron 3 Super 120B (OpenRouter - cloud, free)
echo   Fallback: Qwen2.5 1.5B (GPU Vulkan local)
echo   Watchdog activo (auto-fallback si expira cuota)
echo   Presiona Ctrl+C en la ventana de Leon
echo   para detenerlo.
echo ========================================
echo.
pause
