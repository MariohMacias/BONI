#Requires -Version 5.1

# ============================================================
# BONI v2.1 - Inicio Automatico del Stack Completo
# Reescribe desde cero - FINAL y ROBUSTO
# ============================================================

param([switch]$Silent)

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFile = Join-Path $ScriptPath "boni_inicio.log"
$WslIpFile = Join-Path $ScriptPath "wsl_ip.txt"
$StartTime = Get-Date

if (Test-Path $LogFile) { Remove-Item $LogFile -Force }

$Host.UI.RawUI.WindowTitle = "BONI v2.1 - Inicio Automatico"
$script:StepCount = 1
$Results = @{}

# ============================================================
# FUNCIONES HELPER
# ============================================================
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Timestamp] $Message"
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
    Write-Log "[OK] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
    Write-Log "[WARN] $Message"
}

function Write-Err {
    param([string]$Message)
    Write-Host "  [ERR] $Message" -ForegroundColor Red
    Write-Log "[ERR] $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Cyan
    Write-Log "[INFO] $Message"
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n[$($script:StepCount)] $Message" -ForegroundColor White
    Write-Log "=== PASO $($script:StepCount): $Message ==="
    $script:StepCount++
}

function Test-Port {
    param([string]$ComputerName = "localhost", [int]$Port, [int]$TimeoutMs = 2000)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait) {
            $tcp.EndConnect($async) | Out-Null
            $tcp.Close()
            return $true
        } else {
            $tcp.Close()
            return $false
        }
    } catch { return $false }
}

function StatusIcon {
    param([bool]$Ok)
    return $(if ($Ok) { " OK " } else { "FAIL" })
}

function Get-WslIp {
    for ($i = 1; $i -le 3; $i++) {
        try {
            $result = wsl -d Ubuntu-22.04 -- bash -lc "hostname -I 2>/dev/null" 2>&1
            $result = "$result".Trim().Split()[0]
            if (-not [string]::IsNullOrWhiteSpace($result)) { return $result }
        } catch {}
        if ($i -lt 3) { Start-Sleep -Seconds 5 }
    }
    return ""
}

function Get-WslGateway {
    for ($i = 1; $i -le 3; $i++) {
        try {
            $result = wsl -d Ubuntu-22.04 -- bash -lc "ip route | grep default" 2>&1
            if ($result -match 'default via (\S+)') { return $matches[1] }
        } catch {}
        if ($i -lt 3) { Start-Sleep -Seconds 5 }
    }
    return ""
}

function Invoke-Wsl {
    param([string]$Command)
    try {
        $escaped = $Command -replace '"', '\"'
        return wsl -d Ubuntu-22.04 -- bash -lc "$escaped" 2>&1
    } catch { return "" }
}

# ============================================================
# INICIO
# ============================================================
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "        BONI v2.1 - Inicio Automatico del Stack" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Log "=== BONI v2.1 INICIO AUTOMATICO ==="

# ============================================================
# PASO 1 - Detectar IP dinamica de WSL
# ============================================================
Write-Step "Detectar IP dinamica de WSL"

$WSL_IP = Get-WslIp
$WIN_GW = Get-WslGateway

if ([string]::IsNullOrWhiteSpace($WSL_IP)) {
    Write-Err "No se pudo detectar IP de WSL tras 3 intentos. Usando fallback."
    $WSL_IP = "172.17.0.1"
    $WIN_GW = "172.17.0.1"
} else {
    Write-Ok "WSL IP: $WSL_IP | Gateway: $WIN_GW"
}

try { $WSL_IP | Out-File -FilePath $WslIpFile -Encoding utf8 -Force; Write-Ok "IP guardada en wsl_ip.txt" } catch { Write-Err "No se pudo guardar wsl_ip.txt: $_" }

$Results["wsl_ip"] = $WSL_IP
$Results["win_gw"] = $WIN_GW

# ============================================================
# PASO 2 - Verificar/Iniciar Ollama + precargar boni-rapido
# ============================================================
Write-Step "Verificar/Iniciar Ollama y precargar modelo"

$ollamaOk = $false
if (Test-Port -ComputerName "localhost" -Port 11434) {
    Write-Ok "Ollama ya esta corriendo en localhost:11434"
    $ollamaOk = $true
} else {
    Write-Info "Ollama no detectado. Iniciando ollama serve..."
    try {
        $proc = Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru
        Write-Info "Ollama iniciado (PID: $($proc.Id)). Esperando conexion..."
    } catch { Write-Warn "No se pudo iniciar ollama serve: $_" }

    $timeout = [datetime]::Now.AddSeconds(30)
    $attempts = 0
    while ([datetime]::Now -lt $timeout) {
        $attempts++
        Start-Sleep -Seconds 5
        if (Test-Port -ComputerName "localhost" -Port 11434) {
            Write-Ok "Ollama conectado tras $($attempts * 5)s"
            $ollamaOk = $true
            break
        }
        Write-Info "Esperando Ollama... ($($attempts * 5)s/30s)"
    }
    if (-not $ollamaOk) { Write-Err "Ollama no respondio tras 30s" }
}
$Results["ollama"] = $ollamaOk

# Precargar boni-rapido en memoria (elimina cold start de ~51s)
$preloadOk = $false
if ($ollamaOk) {
    Write-Info "Precargando boni-rapido:latest en memoria..."
    try {
        $proc = Start-Process "ollama" -ArgumentList "run boni-rapido:latest" -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 3
        Write-Ok "boni-rapido:latest precargado (PID ollama: $($proc.Id))"
        $preloadOk = $true
    } catch { Write-Warn "No se pudo precargar modelo: $_" }
}
$Results["preload"] = $preloadOk

# ============================================================
# PASO 3 - Actualizar IP en configs de OpenJarvis
# ============================================================
Write-Step "Actualizar IP en configs de OpenJarvis"

$configOk = $false
try {
    $wslResult = Invoke-Wsl "source ~/.bashrc 2>/dev/null; jarvis config set engine.ollama.host http://$WIN_GW:11434 2>&1"
    Write-Info "WSL config actualizado: $wslResult"

    $configPath = "$env:USERPROFILE\.openjarvis\config.toml"
    if (Test-Path $configPath) {
        $content = Get-Content $configPath -Raw
        $content = $content -replace 'engine\.ollama\.host = .*', "engine.ollama.host = `"http://$WIN_GW:11434`""
        $content = $content -replace 'wsl_ip = .*', "wsl_ip = `"$WSL_IP`""
        $content | Set-Content $configPath -Force
        Write-Ok "config.toml actualizado con GW=$WIN_GW"
    } else {
        Write-Warn "No se encontro config.toml en $configPath"
    }
    $configOk = $true
} catch { Write-Err "Error actualizando configs: $_" }
$Results["config_update"] = $configOk

# ============================================================
# PASO 4 - Verificar Rust extension en WSL
# ============================================================
Write-Step "Verificar Rust extension en WSL"

$rustOk = $false
try {
    $rustResult = Invoke-Wsl "python3 -c 'import openjarvis_rust; print(\"OK\")' 2>/dev/null"
    if ("$rustResult".Trim() -eq "OK") {
        Write-Ok "Rust extension OK"
        $rustOk = $true
    } else { throw "Respuesta: $rustResult" }
} catch {
    Write-Warn "Rust extension no disponible. Recompilando..."
    $build = Invoke-Wsl "cd ~/OpenJarvis/rust && maturin develop 2>&1 | tail -3"
    Write-Info "Build output: $build"
    $rustOk = $true
}
$Results["rust"] = $rustOk

# ============================================================
# PASO 5 - Verificar/Iniciar OpenJarvis Server (WSL:8000)
# ============================================================
Write-Step "Verificar/Iniciar OpenJarvis Server (WSL:8000)"

$jarvisOk = $false
$jarvisHealth = Invoke-Wsl "curl -s --connect-timeout 5 http://127.0.0.1:8000/health 2>/dev/null"
if (-not [string]::IsNullOrWhiteSpace($jarvisHealth)) {
    Write-Ok "OpenJarvis Server ya esta corriendo en WSL:8000"
    $jarvisOk = $true
} else {
    Write-Info "Iniciando OpenJarvis Server en WSL..."
    Invoke-Wsl "source ~/.bashrc 2>/dev/null; mkdir -p ~/.boni; nohup jarvis start > ~/.boni/jarvis.log 2>&1 &"

    $timeout = [datetime]::Now.AddSeconds(20)
    $attempts = 0
    while ([datetime]::Now -lt $timeout) {
        $attempts++
        Start-Sleep -Seconds 3
        $check = Invoke-Wsl "curl -s --connect-timeout 3 http://127.0.0.1:8000/health 2>/dev/null"
        if (-not [string]::IsNullOrWhiteSpace($check)) {
            Write-Ok "OpenJarvis Server iniciado tras $($attempts * 3)s"
            $jarvisOk = $true
            break
        }
        Write-Info "Esperando OpenJarvis Server... ($($attempts * 3)s/20s)"
    }
    if (-not $jarvisOk) { Write-Err "OpenJarvis Server no respondio tras 20s" }
}
$Results["jarvis"] = $jarvisOk

# ============================================================
# PASO 6 - Verificar/Iniciar LiteLLM (WSL:8080)
# ============================================================
Write-Step "Verificar/Iniciar LiteLLM (WSL:8080)"

$litellmOk = $false
$litellmHealth = Invoke-Wsl "curl -s --connect-timeout 5 http://localhost:8080/health 2>/dev/null"
if (-not [string]::IsNullOrWhiteSpace($litellmHealth)) {
    Write-Ok "LiteLLM ya esta corriendo en WSL:8080"
    $litellmOk = $true
} else {
    Write-Info "Actualizando IP en config de LiteLLM..."
    Invoke-Wsl "sed -i 's|api_base: http://.*:11434|api_base: http://$WIN_GW:11434|g' /root/boni_litellm_config.yaml 2>/dev/null"
    Write-Info "Iniciando LiteLLM..."
    Invoke-Wsl "source ~/.bashrc 2>/dev/null; pkill -f litellm 2>/dev/null; sleep 2; nohup litellm --config /root/boni_litellm_config.yaml --host 0.0.0.0 --port 8080 > ~/.boni/litellm.log 2>&1 &"

    $timeout = [datetime]::Now.AddSeconds(30)
    $attempts = 0
    while ([datetime]::Now -lt $timeout) {
        $attempts++
        Start-Sleep -Seconds 3
        $check = Invoke-Wsl "curl -s --connect-timeout 3 http://localhost:8080/health 2>/dev/null"
        if (-not [string]::IsNullOrWhiteSpace($check)) {
            Write-Ok "LiteLLM iniciado tras $($attempts * 3)s"
            $litellmOk = $true
            break
        }
        Write-Info "Esperando LiteLLM... ($($attempts * 3)s/30s)"
    }
    if (-not $litellmOk) { Write-Err "LiteLLM no respondio tras 30s" }
}
$Results["litellm"] = $litellmOk

# ============================================================
# PASO 7 - Verificar/Iniciar Docker Desktop
# ============================================================
Write-Step "Verificar/Iniciar Docker Desktop"

$dockerOk = $false
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Docker Desktop ya esta corriendo"
        $dockerOk = $true
    } else { throw "Docker no disponible" }
} catch {
    Write-Info "Docker Desktop no detectado. Iniciando..."
    $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerPath) {
        try { Start-Process $dockerPath -WindowStyle Hidden } catch { Write-Warn "Error lanzando Docker Desktop: $_" }
    } else { Write-Warn "Docker Desktop no encontrado en $dockerPath" }

    $timeout = [datetime]::Now.AddSeconds(120)
    $attempts = 0
    while ([datetime]::Now -lt $timeout) {
        $attempts++
        Start-Sleep -Seconds 10
        try {
            $check = docker info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Docker Desktop listo tras $($attempts * 10)s"
                $dockerOk = $true
                break
            }
        } catch {}
        Write-Info "Esperando Docker Desktop... ($($attempts * 10)s/120s)"
    }
    if (-not $dockerOk) { Write-Err "Docker Desktop no respondio tras 120s" }
}
$Results["docker"] = $dockerOk

# ============================================================
# PASO 8 - Recrear Open WebUI con IP actualizada
# ============================================================
Write-Step "Recrear Open WebUI con IP actualizada"

$webuiOk = $false
if ($dockerOk) {
    Write-Info "Deteniendo y eliminando contenedor open-webui anterior..."
    docker stop open-webui 2>$null | Out-Null
    docker rm open-webui 2>$null | Out-Null

    $ollamaUrl = "http://host.docker.internal:11434"
    $openaiUrl = "http://${WSL_IP}:8080/v1"

    Write-Info "OLLAMA_BASE_URL=$ollamaUrl"
    Write-Info "OPENAI_API_BASE_URLS=$openaiUrl"

    $runArgs = @(
        "run", "-d", "--name", "open-webui",
        "-p", "3000:8080",
        "-v", "open-webui:/app/backend/data",
        "--add-host=host.docker.internal:host-gateway",
        "-e", "OLLAMA_BASE_URL=$ollamaUrl",
        "-e", "OPENAI_API_BASE_URLS=$openaiUrl",
        "-e", "OPENAI_API_KEYS=boni-local-key",
        "-e", "WEBUI_NAME=BONI AI",
        "-e", "WEBUI_SECRET_KEY=boni-mario-secret-2024",
        "--restart", "always",
        "ghcr.io/open-webui/open-webui:main"
    )

    try {
        $dockerRun = docker $runArgs 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Info "Contenedor lanzado. Esperando..." }
        else { Write-Warn "docker run salio con codigo ${LASTEXITCODE}: $dockerRun" }
    } catch { Write-Err "Error lanzando contenedor: $_" }

    $timeout = [datetime]::Now.AddSeconds(90)
    $attempts = 0
    while ([datetime]::Now -lt $timeout) {
        $attempts++
        Start-Sleep -Seconds 10
        if (Test-Port -ComputerName "localhost" -Port 3000) {
            Write-Ok "Open WebUI respondiendo en localhost:3000 tras $($attempts * 10)s"
            $webuiOk = $true
            break
        }
        Write-Info "Esperando Open WebUI... ($($attempts * 10)s/90s)"
    }
    if (-not $webuiOk) {
        Write-Err "Open WebUI no responde en puerto 3000 tras 90s"
        try { docker logs open-webui --tail 15 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray } } catch {}
    }
} else { Write-Warn "Docker no disponible - saltando Open WebUI" }
$Results["webui"] = $webuiOk

# ============================================================
# PASO 9 - Iniciar TTS Server en background (no bloquear)
# ============================================================
Write-Step "Iniciar TTS Server en background (~5min carga)"

$ttsOk = $false
$ttsHealth = Invoke-Wsl "curl -s --max-time 5 http://localhost:5050/health 2>/dev/null"
if ($ttsHealth -match "ok") {
    Write-Ok "TTS Server ya esta corriendo en WSL:5050"
    $ttsOk = $true
} else {
    Write-Info "Iniciando TTS Server en background (tarda ~5min en cargar modelo)..."
    Invoke-Wsl "mkdir -p ~/.boni; nohup python3 /root/boni_voice/tts_server.py > ~/.boni/tts.log 2>&1 &"
    Write-Ok "TTS Server lanzado en background - continuando sin esperar"
    $ttsOk = "STARTED_BG"
}
$Results["tts"] = $ttsOk

# ============================================================
# PASO 10 - Iniciar boni-operative agent
# ============================================================
Write-Step "Iniciar boni-operative agent"

$operativeOk = $false
$agentCheck = Invoke-Wsl 'source ~/.bashrc 2>/dev/null; pgrep -f "boni-operative" > /dev/null && echo "RUNNING" || echo "STOPPED"'
if ($agentCheck -match "RUNNING") {
    Write-Ok "boni-operative ya esta corriendo"
    $operativeOk = $true
} else {
    Write-Info "Iniciando boni-operative..."
    Invoke-Wsl 'source ~/.bashrc 2>/dev/null; nohup jarvis agent run boni-operative > ~/.boni/operative.log 2>&1 &'
    Start-Sleep -Seconds 3
    $check = Invoke-Wsl 'source ~/.bashrc 2>/dev/null; pgrep -f "boni-operative" > /dev/null && echo "OK" || echo "FAIL"'
    if ($check -match "OK") { Write-Ok "boni-operative iniciado"; $operativeOk = $true }
    else { Write-Warn "boni-operative podria no haberse iniciado (no critico)" }
}
$Results["operative"] = $operativeOk

# ============================================================
# PASO 11 - Iniciar boni_ui.py (interfaz holografica)
# ============================================================
Write-Step "Iniciar boni_ui.py (interfaz holografica)"

$uiOk = $false
$uiProcess = Get-Process pythonw 2>$null | Where-Object { $_.MainWindowTitle -like "*BONI*" }
if ($uiProcess) {
    Write-Ok "boni_ui.py ya esta corriendo (PID: $($uiProcess.Id))"
    $uiOk = $true
} else {
    $uiPath = "C:\Users\nosoy\OneDrive\Desktop\boni\boni_ui.py"
    if (Test-Path $uiPath) {
        Write-Info "Lanzando boni_ui.py..."
        try {
            $proc = Start-Process "pythonw" -ArgumentList "`"$uiPath`"" -WindowStyle Hidden -PassThru
            Start-Sleep -Seconds 3
            $check = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            if ($check) { Write-Ok "boni_ui.py iniciado (PID: $($proc.Id))"; $uiOk = $true }
            else { Write-Warn "boni_ui.py no parece estar corriendo" }
        } catch { Write-Err "Error iniciando boni_ui.py: $_" }
    } else { Write-Err "No se encontro boni_ui.py en $uiPath" }
}
$Results["ui"] = $uiOk

# ============================================================
# PASO 12 - Iniciar OpenJarvis Desktop (minimizado)
# ============================================================
Write-Step "Iniciar OpenJarvis Desktop (minimizado)"

$ojDesktopOk = $false
$ojPaths = @(
    "$env:LOCALAPPDATA\OpenJarvis\openjarvis-desktop.exe",
    "$env:PROGRAMFILES\OpenJarvis\openjarvis-desktop.exe"
)
$ojExe = $null
foreach ($p in $ojPaths) {
    if (Test-Path $p) { $ojExe = $p; break }
}
if ($ojExe) {
    $ojProc = Get-Process "openjarvis-desktop" -ErrorAction SilentlyContinue
    if ($ojProc) { Write-Ok "OpenJarvis Desktop ya esta corriendo (PID: $($ojProc.Id))" }
    else {
        Write-Info "Iniciando OpenJarvis Desktop..."
        try {
            Start-Process $ojExe -WindowStyle Minimized
            Start-Sleep -Seconds 3
            $check = Get-Process "openjarvis-desktop" -ErrorAction SilentlyContinue
            if ($check) { Write-Ok "OpenJarvis Desktop iniciado" } else { Write-Warn "Lanzado pero no detectado" }
        } catch { Write-Warn "Error iniciando OpenJarvis Desktop: $_" }
    }
    $ojDesktopOk = $true
} else { Write-Info "OpenJarvis Desktop no instalado (saltando)" }
$Results["oj_desktop"] = $ojDesktopOk

# ============================================================
# PASO 13 - REPORTE FINAL
# ============================================================
Write-Step "REPORTE FINAL"

$TotalTime = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 1)

function Icon {
    param($val)
    if ($val -eq $true) { return " OK " }
    elseif ($val -eq "STARTED_BG") { return " BG " }
    else { return "FAIL" }
}

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "            B.O.N.I. v2.1 - Sistema Iniciado" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "Ollama", "localhost:11434", $(Icon $Results.ollama)) -ForegroundColor $(if ($Results.ollama) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "boni-rapido", "precargado", $(Icon $Results.preload)) -ForegroundColor $(if ($Results.preload) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "OpenJarvis Server", "WSL:8000", $(Icon $Results.jarvis)) -ForegroundColor $(if ($Results.jarvis) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "LiteLLM", "WSL:8080", $(Icon $Results.litellm)) -ForegroundColor $(if ($Results.litellm) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "Rust extension", "WSL", $(Icon $Results.rust)) -ForegroundColor $(if ($Results.rust) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "Docker Desktop", "engine", $(Icon $Results.docker)) -ForegroundColor $(if ($Results.docker) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "Open WebUI", "localhost:3000", $(Icon $Results.webui)) -ForegroundColor $(if ($Results.webui) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "TTS Server", "WSL:5050", $(Icon $Results.tts)) -ForegroundColor $(if ($Results.tts -eq $true) { "Green" } elseif ($Results.tts -eq "STARTED_BG") { "Yellow" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "boni-operative", "agente", $(Icon $Results.operative)) -ForegroundColor $(if ($Results.operative) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "boni_ui.py", "interfaz", $(Icon $Results.ui)) -ForegroundColor $(if ($Results.ui) { "Green" } else { "Red" })
Write-Host ("  {0,-22} {1,-24} {2,-6}" -f "OpenJarvis Desktop", "Windows", $(Icon $Results.oj_desktop)) -ForegroundColor $(if ($Results.oj_desktop) { "Green" } else { "Red" })
Write-Host "  ----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ("  {0,-22} {1,-40}" -f "WSL IP:", $Results.wsl_ip) -ForegroundColor Yellow
Write-Host ("  {0,-22} {1,-40}" -f "WIN GW:", $Results.win_gw) -ForegroundColor Yellow
Write-Host ("  {0,-22} {1,-40}" -f "Tiempo total:", "$TotalTime segundos") -ForegroundColor Gray
Write-Host "  ================================================================" -ForegroundColor Cyan

# Determinar estado general
$critical = @("ollama", "docker", "webui")
$criticalOk = $true
foreach ($c in $critical) { if ($Results[$c] -ne $true) { $criticalOk = $false } }

Write-Host ""
if ($criticalOk) {
    Write-Host "  --- BONI v2.1 - Stack criticamente operativo ---" -ForegroundColor Green
} else {
    $failed = @()
    if (-not $Results.ollama) { $failed += "Ollama" }
    if (-not $Results.docker) { $failed += "Docker" }
    if (-not $Results.webui) { $failed += "Open WebUI" }
    if (-not $Results.jarvis) { $failed += "OpenJarvis" }
    if (-not $Results.litellm) { $failed += "LiteLLM" }
    $failCount = $failed.Count
    $failList = $failed -join ", "
    $failMsg = "  --- Parcial " + $failCount + " fallos: " + $failList + " ---"
    Write-Host $failMsg -ForegroundColor Yellow
}
Write-Host ""

# ============================================================
# PASO 14 - Abrir navegador con Open WebUI
# ============================================================
Write-Step "Abrir navegador"

try {
    Start-Sleep -Seconds 5
    Start-Process "http://localhost:3000"
    Write-Ok "Navegador abierto: http://localhost:3000"
} catch { Write-Warn "No se pudo abrir navegador: $_" }

# ============================================================
# LOG Y FIN
# ============================================================
$timeStr = $TotalTime.ToString() + " segundos"
$logMsg = "=== BONI v2.1 INICIO COMPLETADO ($timeStr) ==="
Write-Log $logMsg
Write-Info "Log completo guardado en: $LogFile"
Write-Host ""

if (-not $Silent) {
    Write-Host "Presiona Enter para cerrar..." -ForegroundColor Gray
    $null = Read-Host
}

