@echo off
chcp 65001 >nul
title BONI Chat Web v2.1
set DIR=%~dp0
echo ====================================
echo   B.O.N.I. v2.1 - Web Chat
echo ====================================
echo.

:: Iniciar sandbox server si no esta corriendo
echo [1/3] Sandbox Server...
curl -s --connect-timeout 2 http://localhost:8765/ >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Sandbox ya responde en :8765
) else (
    start /B pythonw "%DIR%boni_sandbox_server.py"
    echo   [INI] Sandbox lanzado en background
)

echo [2/3] Proxy...
start /B python "%DIR%boni_proxy.py"
echo   [INI] Proxy lanzado en :8080

echo [3/3] Navegador...
timeout /t 2 /nobreak >nul
start http://localhost:8080
echo   [OK] Abriendo web chat

echo ====================================
echo   Presiona cualquier tecla para cerrar todo
echo ====================================
pause

:: Cleanup al cerrar
taskkill /f /im python.exe >nul 2>&1
taskkill /f /im pythonw.exe >nul 2>&1
echo   Stack detenido.
