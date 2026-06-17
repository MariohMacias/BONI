@echo off
title llama.cpp GPU Server (Qwen2.5 1.5B)
echo ========================================
echo   llama.cpp GPU Server (Vulkan)
echo   Modelo: Qwen2.5 1.5B Instruct
echo   Puerto: 8080
echo ========================================
echo.
echo [1/2] Verificando GPU Vulkan...
python -c "from llama_cpp import Llama; print('GPU: OK')" 2>nul
if %errorlevel% neq 0 (
    echo [!] Error: llama-cpp-python no instalado
    pause
    exit /b 1
)
echo [OK] GPU Vulkan lista

echo [2/2] Iniciando servidor...
python -m llama_cpp.server ^
  --model "C:\Users\nosoy\.leon\local-models\Qwen2.5-1.5B-Instruct-Q4_K_M.gguf" ^
  --n_gpu_layers -1 ^
  --n_threads 4 ^
  --host 127.0.0.1 ^
  --port 8080

if %errorlevel% neq 0 (
    echo [!] Error iniciando servidor
    pause
    exit /b 1
)
