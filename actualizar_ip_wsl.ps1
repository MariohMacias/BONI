# BONI - Actualizar IP de WSL y gateway
# Corre en PowerShell como Administrador
$ErrorActionPreference = "SilentlyContinue"

Write-Host "=== Detectando IPs de WSL ===" -ForegroundColor Cyan

# Obtener IP de WSL
$wslIP = (wsl -d Ubuntu-22.04 hostname -I).Trim().Split()[0]
Write-Host "WSL IP: $wslIP" -ForegroundColor Yellow

# Obtener gateway (Windows host)
$winGW = (wsl -d Ubuntu-22.04 bash -c "ip route | grep default | awk '{print \$3}'").Trim()
Write-Host "Windows Gateway: $winGW" -ForegroundColor Yellow

if (-not $wslIP -or -not $winGW) {
    Write-Host "ERROR: No se detectaron IPs. WSL esta corriendo?" -ForegroundColor Red
    exit 1
}

# Actualizar config de OpenJarvis (CLI)
Write-Host "`nActualizando config CLI de OpenJarvis..." -ForegroundColor Cyan
wsl -d Ubuntu-22.04 bash -c "jarvis config set engine.ollama.host http://${winGW}:11434 2>/dev/null"
Write-Host "  engine.ollama.host = http://${winGW}:11434" -ForegroundColor Green

# Verificar conectividad
Write-Host "`nVerificando conectividad..." -ForegroundColor Cyan
$ollamaOk = (curl.exe -s --max-time 5 "http://localhost:11434/api/tags" 2>$null) -match "models"
$proxyOk = (curl.exe -s --max-time 5 "http://${wslIP}:8080/health" 2>$null) -match "healthy"

if ($ollamaOk) { Write-Host "  Ollama:   OK (localhost:11434)" -ForegroundColor Green }
else { Write-Host "  Ollama:   NO RESPONDE" -ForegroundColor Red }

if ($proxyOk) { Write-Host "  Proxy:    OK (${wslIP}:8080)" -ForegroundColor Green }
else { Write-Host "  Proxy:    NO RESPONDE" -ForegroundColor Red }

# Crear/actualizar .env con IPs
$envFile = "$env:USERPROFILE\OneDrive\Desktop\boni\.env"
@"
WSL_IP=$wslIP
WIN_GW=$winGW
JARVIS_API=http://${wslIP}:8080/v1
JARVIS_KEY=boni-local-key
OLLAMA_URL=http://localhost:11434
"@ | Out-File -FilePath $envFile -Encoding ASCII

Write-Host "`n.env actualizado: $envFile" -ForegroundColor Green
Write-Host "`n=== Listo ===" -ForegroundColor Cyan
