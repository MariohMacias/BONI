@echo off
:: BONI - OpenJarvis Launcher
:: Abre una terminal WSL con OpenJarvis configurado para usar qwen2.5:3b via Ollama local
wsl -d Ubuntu-22.04 bash -c "cd ~ && exec bash -l"
:: Alternativa directa: wsl -d Ubuntu-22.04 jarvis --mode chat
