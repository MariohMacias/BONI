@echo off
title Descargando Qwen2.5-0.5B-Instruct-Q4_K_M.gguf
echo ========================================
echo   Descargando Qwen2.5 0.5B Instruct
echo   Modelo: GGUF Q4_K_M (~400 MB)
echo ========================================
echo.
set MODEL_DIR=%USERPROFILE%\.leon\local-models
set MODEL_PATH=%MODEL_DIR%\Qwen2.5-0.5B-Instruct-Q4_K_M.gguf

if exist "%MODEL_PATH%" (
    echo [OK] Modelo ya existe
    for %%I in ("%MODEL_PATH%") do echo Tamano: %%~zI bytes
    pause
    exit /b 0
)

if not exist "%MODEL_DIR%" mkdir "%MODEL_DIR%"

echo [1/2] Descargando modelo desde HuggingFace (puede tardar)...
echo.
python -c "import huggingface_hub; huggingface_hub.hf_hub_download(repo_id='bartowski/Qwen2.5-0.5B-Instruct-GGUF', filename='Qwen2.5-0.5B-Instruct-Q4_K_M.gguf', local_dir=r'%MODEL_DIR%', local_dir_use_symlinks=False)"

if %errorlevel% neq 0 (
    echo [!] Error descargando modelo
    echo Prueba: huggingface-cli download bartowski/Qwen2.5-0.5B-Instruct-GGUF Qwen2.5-0.5B-Instruct-Q4_K_M.gguf --local-dir "%MODEL_DIR%"
    pause
    exit /b 1
)

echo.
echo [OK] Descarga completa!
echo [2/2] Verificando integridad...
if exist "%MODEL_PATH%" (
    for %%I in ("%MODEL_PATH%") do echo Tamano: %%~zI bytes
    echo [OK] Modelo listo en:
    echo   %MODEL_PATH%
) else (
    echo [!] Error: archivo no encontrado
    pause
    exit /b 1
)

pause
