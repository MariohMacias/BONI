# BONI Tools

Herramientas para ejecutar Leon AI con personalidad BONI.

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `INICIAR_LEON_BONI.bat` | Inicia Leon + GPU server + watchdog |
| `INICIAR_LLAMACPP_SERVER.bat` | Servidor llama.cpp con GPU Vulkan |
| `LEON_WATCHDOG.ps1` | Auto-fallback OpenRouter ↔ GPU local |
| `DESCARGAR_QWEN_0.5B.bat` | Descarga modelo Qwen2.5-0.5B GGUF |
| `finetune/` | Dataset + Colab notebook para fine-tuning |

## Requisitos

- [Leon AI](https://github.com/leon-ai/leon) en `C:\Users\nosoy\OneDrive\Desktop\LEON_BONI`
- llama-cpp-python con soporte Vulkan
- OpenRouter API key (opcional, para cloud)

## Fine-tuning BONI

1. Sube `finetune/dataset/` a Google Drive
2. Abre `finetune/BONI_FINETUNE_COLAB.ipynb` en Colab
3. Ejecuta con GPU T4
4. Copia el GGUF generado a `~/.leon/local-models/`
