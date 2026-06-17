@echo off
chcp 65001 >nul
title Instalar Whisper para BONI
echo ============================================
echo Instalando faster-whisper + sounddevice...
echo ============================================
echo.
echo Esto descarga ~300 MB, puede tardar varios minutos.
echo.
pip install faster-whisper sounddevice numpy
echo.
if %errorlevel% == 0 (
    echo [OK] Instalacion completada. Cierra y abre BONI.
) else (
    echo [ERROR] Fallo la instalacion. Revisa tu conexion.
)
echo.
pause
