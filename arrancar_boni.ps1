# BONI v2.1 — Startup script
# Run as Administrator for best results

Write-Host "=== BONI v2.1 — Startup ===" -ForegroundColor Cyan

# 1. Ollama
try {
    $ollama = curl.exe -s --max-time 3 http://localhost:11434/api/tags
    if ($ollama) { Write-Host "✅ Ollama OK" -ForegroundColor Green }
} catch {
    Write-Host "🔄 Arrancando Ollama..." -ForegroundColor Yellow
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
}

# 2. BONI Web UI
$env:JARVIS_URL = "http://172.29.191.230:8080"
$env:JARVIS_KEY = "boni-local-key"
$env:PORT = "3001"

$proc = Get-Process -Name "pythonw" -ErrorAction SilentlyContinue
if (-not $proc) {
    Start-Process "pythonw" -ArgumentList "C:\Users\nosoy\OneDrive\Desktop\boni\boni_webui.py"
    Write-Host "✅ BONI Web UI iniciado en :3001" -ForegroundColor Green
} else {
    Write-Host "✅ BONI Web UI ya está corriendo" -ForegroundColor Green
}

# 3. Abrir navegador
Start-Process "http://localhost:3001"

Write-Host ""
Write-Host "=== BONI v2.1 activo ===" -ForegroundColor Cyan
Write-Host "  BONI Web UI: http://localhost:3001"
Write-Host "  Proxy Ollama: http://172.29.191.230:8080"
Write-Host "  Ollama:      http://localhost:11434"
Write-Host ""
Write-Host "Para arrancar Open WebUI (Docker):" -ForegroundColor Yellow
Write-Host "  1. Abre Docker Desktop como Administrador"
Write-Host "  2. Ejecuta: docker run -d --name open-webui -p 3000:8080 \"
Write-Host "       -v open-webui:/app/backend/data \"
Write-Host "       --add-host=host.docker.internal:host-gateway \"
Write-Host '       -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \'
Write-Host '       -e WEBUI_NAME="BONI AI" \'
Write-Host "       --restart always \"
Write-Host "       ghcr.io/open-webui/open-webui:main"
