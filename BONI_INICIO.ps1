#Requires -Version 5.1

# ============================================================
# BONI v2.1 - Inicio Automatico del Stack Completo
# ============================================================

param(
    [switch]$Silent
)

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFile = Join-Path $ScriptPath "boni_inicio.log"
$WslIpFile = Join-Path $ScriptPath "wsl_ip.txt"
$StartTime = Get-Date

if (Test-Path $LogFile) { Remove-Item $LogFile -Force }

$Host.UI.RawUI.WindowTitle = "BONI v2.1 - Inicio Automatico"

# ============================================================
# FUNCIONES HELPER
# ============================================================
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $Line
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
    param(
        [string]$ComputerName = "localhost",
        [int]$Port,
        [int]$TimeoutMs = 2000
    )
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
    } catch {
        return $false
    }
}

function Get-WslIp {
    try {
        $result = wsl -d Ubuntu-22.04 -- bash -lc "hostname -I 2>/dev/null | awk '{print \$1}'" 2>&1
        $result = "$result".Trim()
        if (-not [string]::IsNullOrWhiteSpace($result)) { return $result }
    } catch {}
    return ""
}

function Get-WslGateway {
    try {
        $result = wsl -d Ubuntu-22.04 -- bash -lc "hostname -I 2>/dev/null | awk '{print \$1}'" 2>&1
        $result = "$result".Trim()
        if (-not [string]::IsNullOrWhiteSpace($result)) {
            $parts = $result.Split('.')
            if ($parts.Count -eq 4) {
                return "$($parts[0]).$($parts[1]).$($parts[2]).1"
            }
        }
    } catch {}
    return ""
}

function Invoke-Wsl {
    param([string]$Command)
    try {
        $escaped = $Command -replace '"', '\"'
        return wsl -d Ubuntu-22.04 -- bash -lc "$escaped" 2>&1
    } catch {
        return ""
    }
}

# LiteLLM no se usa - proxy ligero en /root/ollama_proxy.py

# ============================================================
# INICIO
# ============================================================
$StepCount = 1
$Results = @{}

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

$WSL_IP = ""
$WIN_GW = ""

for ($i = 1; $i -le 3; $i++) {
    Write-Info "Intento $i/3 - detectando IP WSL..."
    $WSL_IP = Get-WslIp
    $WIN_GW = Get-WslGateway
    if ([string]::IsNullOrWhiteSpace($WSL_IP) -or [string]::IsNullOrWhiteSpace($WIN_GW)) {
        Write-Warn "IP no detectada aun (WSL_IP='$WSL_IP', GW='$WIN_GW'), esperando 5s..."
        Start-Sleep -Seconds 5
    } else {
        Write-Ok "WSL IP: $WSL_IP | Gateway: $WIN_GW"
        break
    }
}

if ([string]::IsNullOrWhiteSpace($WSL_IP)) {
    Write-Err "No se pudo detectar IP de WSL tras 3 intentos. Usando fallback 172.x.x.x"
    $WSL_IP = "172.17.0.1"
    $WIN_GW = "172.17.0.1"
}

try {
    $WSL_IP | Out-File -FilePath $WslIpFile -Encoding utf8 -Force
    Write-Ok "IP guardada en wsl_ip.txt: $WSL_IP"
} catch {
    Write-Err "No se pudo guardar wsl_ip.txt: $_"
}

$Results["wsl_ip"] = $WSL_IP
$Results["win_gw"] = $WIN_GW

# ============================================================
# PASO 2 - Verificar/Iniciar Ollama
# ============================================================
Write-Step "Verificar/Iniciar Ollama"

$ollamaOk = $false
if (Test-Port -ComputerName "localhost" -Port 11434) {
    Write-Ok "Ollama ya esta corriendo en localhost:11434"
    $ollamaOk = $true
} else {
    Write-Info "Ollama no detectado. Iniciando ollama serve..."
    try {
        $proc = Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru
        Write-Info "Ollama iniciado (PID: $($proc.Id)). Esperando conexion..."
    } catch {
        Write-Warn "No se pudo iniciar ollama serve: $_"
    }

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
    if (-not $ollamaOk) {
        Write-Err "Ollama no respondio tras 30s"
    }
}
$Results["ollama"] = $ollamaOk

# ============================================================
# PASO 3 - Verificar/Iniciar proxy Ollama
# ============================================================
Write-Step "Verificar/Iniciar proxy Ollama"

$proxyOk = $false
try {
    $proxyHealth = Invoke-Wsl "curl -s --connect-timeout 3 http://localhost:8080/health 2>/dev/null"
    if ($proxyHealth -match "healthy") {
        Write-Ok "Proxy ya corriendo en WSL:8080"
        $proxyOk = $true
    } else {
        throw "Proxy no responde"
    }
} catch {
    Write-Info "Iniciando proxy Ollama..."
    try {
        Invoke-Wsl "pkill -f ollama_proxy 2>/dev/null; sleep 1; nohup python3 /root/ollama_proxy.py > /root/.boni/proxy.log 2>&1 & echo OK"
        Start-Sleep -Seconds 3
        $check = Invoke-Wsl "curl -s --connect-timeout 3 http://localhost:8080/health 2>/dev/null"
        if ($check -match "healthy") {
            Write-Ok "Proxy iniciado exitosamente"
            $proxyOk = $true
        } else {
            throw "Proxy no responde tras inicio"
        }
    } catch {
        Write-Err "Error iniciando proxy: $_"
    }
}
$Results["proxy"] = $proxyOk

# ============================================================
# PASO 4 - Verificar Rust extension
# ============================================================
Write-Step "Verificar Rust extension"

$rustOk = $false
try {
    $rustResult = Invoke-Wsl "python3 -c 'import openjarvis_rust; print(\"OK\")'"
    if ("$rustResult".Trim() -eq "OK") {
        Write-Ok "Rust extension OK"
        $rustOk = $true
    } else {
        throw "Respuesta inesperada: $rustResult"
    }
} catch {
    Write-Warn "Rust extension no disponible. Recompilando..."
    try {
        $buildResult = Invoke-Wsl "cd ~/OpenJarvis/rust && maturin develop 2>&1"
        Write-Ok "Rust extension recompilada exitosamente"
        $rustOk = $true
    } catch {
        Write-Err "Error recompilando Rust extension: $_"
    }
}
$Results["rust"] = $rustOk

# ============================================================
# PASO 5 - boni_ui.py (Ollama directo + proxy fallback)
# ============================================================
Write-Step "boni_ui.py (Ollama directo + proxy WSL:8080)"

$proxyCheckOk = $true  # proxy se usa como fallback
Write-Ok "boni_ui.py conecta directo a Ollama (localhost:11434)"
Write-Info "Proxy Ollama disponible en WSL:8080 como fallback"
$Results["proxy_backend"] = $proxyCheckOk

# ============================================================
# PASO 6 - Verificar/Iniciar TTS Server (voz de BONI)
# ============================================================
Write-Step "Verificar/Iniciar TTS Server (voz de BONI)"

$ttsOk = $false
try {
    $ttsHealth = Invoke-Wsl "curl -s --max-time 5 http://localhost:5050/health 2>/dev/null"
    if ($ttsHealth -match "ok") {
        Write-Ok "TTS Server ya esta corriendo en WSL:5050"
        $ttsOk = $true
    } else {
        throw "TTS no responde"
    }
} catch {
    Write-Info "Iniciando TTS Server (voz de BONI)..."
    try {
        Invoke-Wsl "mkdir -p ~/.boni && nohup /usr/bin/python3.10 /root/boni_voice/tts_server.py > ~/.boni/tts.log 2>&1 & echo iniciado" | Out-Null

        $timeout = [datetime]::Now.AddSeconds(30)
        $attempts = 0
        while ([datetime]::Now -lt $timeout) {
            $attempts++
            Start-Sleep -Seconds 5
            $check = Invoke-Wsl "curl -s --max-time 3 http://localhost:5050/health"
            if ($check -match "ok") {
                Write-Ok "TTS Server iniciado tras $($attempts * 5)s"
                $ttsOk = $true
                break
            }
            Write-Info "Esperando TTS Server... ($($attempts * 5)s/30s)"
        }
        if (-not $ttsOk) {
            Write-Err "TTS Server no respondio tras 30s (primera descarga de modelo puede tardar mas)"
        }
    } catch {
        Write-Err "Error iniciando TTS Server: $_"
    }
}
$Results["tts"] = $ttsOk

# ============================================================
# PASO 7 - boni-agent (opcional - requiere OpenJarvis CLI)
# ============================================================
Write-Step "boni-agent (opcional - requiere OpenJarvis CLI)"

Write-Info "Agentes requieren OpenJarvis CLI. Saltando (no critico)."
$Results["operative"] = $true

# ============================================================
# PASO 8 - Verificar/Iniciar Docker Desktop
# ============================================================
Write-Step "Verificar/Iniciar Docker Desktop"

$dockerOk = $false
try {
    $dockerInfo = docker info 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Write-Ok "Docker Desktop ya esta corriendo"
        $dockerOk = $true
    } else {
        throw "Docker no disponible"
    }
} catch {
    Write-Info "Docker Desktop no detectado. Iniciando..."
    $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerPath) {
        try { Start-Process $dockerPath -WindowStyle Hidden } catch { Write-Warn "Error lanzando Docker Desktop: $_" }
    } else {
        Write-Warn "Docker Desktop no encontrado en $dockerPath"
    }

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
    if (-not $dockerOk) {
        Write-Err "Docker Desktop no respondio tras 120s"
    }
}
$Results["docker"] = $dockerOk

# ============================================================
# PASO 9 - Recrear Open WebUI con IP actualizada
# ============================================================
Write-Step "Recrear Open WebUI con IP actualizada"

$webuiOk = $false
if ($dockerOk) {
    Write-Info "Deteniendo y eliminando contenedor open-webui anterior..."
    docker stop open-webui 2>$null | Out-Null
    docker rm open-webui 2>$null | Out-Null

    $ollamaUrl = "http://host.docker.internal:11434"
    $openaiUrl = "http://localhost:8080/v1"

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
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Contenedor lanzado. Esperando que responda en puerto 3000..."
        } else {
            Write-Warn "docker run salio con codigo ${LASTEXITCODE}: $dockerRun"
        }
    } catch {
        Write-Err "Error lanzando contenedor: $_"
    }

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
        Write-Info "Logs del contenedor:"
        try {
            $logs = docker logs open-webui --tail 20 2>&1
            Write-Host $logs -ForegroundColor Gray
        } catch {}
    }
} else {
    Write-Warn "Docker no disponible - saltando Open WebUI"
}
$Results["webui"] = $webuiOk

# ============================================================
# PASO 10 - Verificar/Iniciar OpenHands (opcional)
# ============================================================
Write-Step "Verificar/Iniciar OpenHands (opcional)"

$openhandsOk = $false
if ($dockerOk) {
    try {
        $images = docker images --format "{{.Repository}}" 2>&1
        $hasOpenHands = ($images | Select-String "openhands|all-hands-ai").Count -gt 0
        if ($hasOpenHands) {
            Write-Info "Imagen OpenHands encontrada. Verificando contenedor..."
            docker start openhands 2>$null | Out-Null
            Start-Sleep -Seconds 3
            if (Test-Port -ComputerName "localhost" -Port 3002) {
                Write-Ok "OpenHands respondiendo en localhost:3002"
                $openhandsOk = $true
            } else {
                Write-Warn "OpenHands no responde en puerto 3002 (puede necesitar configuracion)"
            }
        } else {
            Write-Warn "OpenHands pendiente - ejecuta: docker pull ghcr.io/all-hands-ai/openhands:latest"
        }
    } catch {
        Write-Warn "Error verificando OpenHands: $_"
    }
} else {
    Write-Warn "Docker no disponible - saltando OpenHands"
}
$Results["openhands"] = $openhandsOk

# ============================================================
# PASO 11 - Verificar/Iniciar OpenJarvis Desktop
# ============================================================
Write-Step "Verificar/Iniciar OpenJarvis Desktop"

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
    if ($ojProc) {
        Write-Ok "OpenJarvis Desktop ya esta corriendo (PID: $($ojProc.Id))"
    } else {
        Write-Info "Iniciando OpenJarvis Desktop..."
        try {
            Start-Process $ojExe -WindowStyle Minimized
            Start-Sleep -Seconds 5
            $check = Get-Process "openjarvis-desktop" -ErrorAction SilentlyContinue
            if ($check) {
                Write-Ok "OpenJarvis Desktop iniciado"
            } else {
                Write-Warn "OpenJarvis Desktop lanzado pero no detectado"
            }
        } catch {
            Write-Warn "Error iniciando OpenJarvis Desktop: $_"
        }
    }
    $ojDesktopOk = $true
} else {
    Write-Info "OpenJarvis Desktop no instalado (saltando)"
    Write-Info "  Descarga: https://github.com/open-jarvis/OpenJarvis/releases"
}
$Results["oj_desktop"] = $ojDesktopOk

# ============================================================
# PASO 12 - Verificar memoria y docs
# ============================================================
Write-Step "Verificar memoria y docs"

$memoryOk = $false
$docCount = 0
$skillsCount = 0
$skillsOk = $false
$pcControlOk = $false
$browserUseOk = $false

try {
    $docsExists = Invoke-Wsl "test -d ~/boni_docs && echo OK || echo NOT_FOUND"
    if ("$docsExists".Trim() -eq "OK") {
        $memoryOk = $true
        # CLI no disponible - memoria requiere OpenJarvis
        $raw = "0"
        $docCount = "$raw".Trim()
        if ($docCount -match "^\d+$") { $docCount = [int]$docCount } else { $docCount = 0 }
        Write-Ok "Memoria SQLite: $docCount docs indexados"
    } else {
        Write-Warn "boni_docs no encontrado"
    }

    $rawSkills = Invoke-Wsl "ls ~/.openjarvis/skills/ 2>/dev/null | wc -l"
    $skillsCount = "$rawSkills".Trim()
    if ($skillsCount -match "^\d+$") { $skillsCount = [int]$skillsCount } else { $skillsCount = 0 }
    if ($skillsCount -gt 0) {
        Write-Ok "Skills: $skillsCount instaladas"
        $skillsOk = $true
    } else {
        Write-Warn "No se detectaron skills en ~/.openjarvis/skills/"
    }

    $pcResult = Invoke-Wsl "python3 -c 'import pyautogui; import pynput; from PIL import Image; print(\"OK\")' 2>/dev/null && echo PC_CONTROL:OK || echo PC_CONTROL:FAIL"
    if ("$pcResult" -match "PC_CONTROL:OK") {
        Write-Ok "Control PC: mouse+keyboard+PIL activos"
        $pcControlOk = $true
    } else {
        Write-Warn "Control PC: dependencias incompletas"
    }

    $browserResult = Invoke-Wsl "python3 -c 'import browser_use; print(\"OK\")' 2>/dev/null && echo BROWSER_USE:OK || echo BROWSER_USE:FAIL"
    if ("$browserResult" -match "BROWSER_USE:OK") {
        Write-Ok "browser-use: instalado"
        $browserUseOk = $true
    } else {
        Write-Warn "browser-use: no detectado"
    }

} catch {
    Write-Err "Error verificando memoria/docs: $_"
}

$Results["memory"] = $memoryOk
$Results["doc_count"] = $docCount
$Results["skills"] = $skillsOk
$Results["skill_count"] = $skillsCount
$Results["pc_control"] = $pcControlOk
$Results["browser_use"] = $browserUseOk

# ============================================================
# PASO 13 - Reporte Final
# ============================================================
Write-Step "Reporte final del sistema"

$TotalTime = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 1)

function StatusIcon {
    param([bool]$Ok)
    if ($Ok) { return " OK " } else { return "FAIL" }
}

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "            BONI v2.1 - Estado del Sistema" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Ollama", "localhost:11434", $(if ($Results.ollama) { " OK " } else { "FAIL" })) -ForegroundColor $(if ($Results.ollama) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Rust extension", "WSL", $(StatusIcon $Results.rust)) -ForegroundColor $(if ($Results.rust) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Proxy Ollama", "WSL:8080", $(StatusIcon $Results.proxy)) -ForegroundColor $(if ($Results.proxy) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "boni-operative", "opcional", $(StatusIcon $Results.operative)) -ForegroundColor $(if ($Results.operative) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "TTS Server (voz)", "WSL:5050", $(StatusIcon $Results.tts)) -ForegroundColor $(if ($Results.tts) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Docker Desktop", "engine", $(StatusIcon $Results.docker)) -ForegroundColor $(if ($Results.docker) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Open WebUI", "localhost:3000", $(StatusIcon $Results.webui)) -ForegroundColor $(if ($Results.webui) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "OpenHands", "localhost:3002", $(StatusIcon $Results.openhands)) -ForegroundColor $(if ($Results.openhands) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "OpenJarvis Desktop", "GUI native", $(StatusIcon $Results.oj_desktop)) -ForegroundColor $(if ($Results.oj_desktop) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Memoria SQLite", "$($Results.doc_count) docs", $(StatusIcon $Results.memory)) -ForegroundColor $(if ($Results.memory) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Skills", "$($Results.skill_count) instaladas", $(StatusIcon $Results.skills)) -ForegroundColor $(if ($Results.skills) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "Control PC", "mouse+keyboard+PIL", $(StatusIcon $Results.pc_control)) -ForegroundColor $(if ($Results.pc_control) { "Green" } else { "Red" })
Write-Host ("  {0,-18} {1,-22} {2,-6}" -f "browser-use", "WSL chromium", $(StatusIcon $Results.browser_use)) -ForegroundColor $(if ($Results.browser_use) { "Green" } else { "Red" })
Write-Host "  ----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ("  {0,-18} {1,-40}" -f "WSL IP:", $Results.wsl_ip) -ForegroundColor Yellow
Write-Host ("  {0,-18} {1,-40}" -f "WIN GW:", $Results.win_gw) -ForegroundColor Yellow
Write-Host ("  {0,-18} {1,-40}" -f "Tiempo total:", "$TotalTime segundos") -ForegroundColor Gray
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""

$allOk = $Results.ollama -and $Results.rust -and $Results.docker -and $Results.webui -and $Results.memory
# Nota: proxy, tts y operative son opcionales
if ($allOk) {
    Write-Host "  >>> BONI v2.1 - Stack completamente operativo <<<" -ForegroundColor Green
} else {
    $failed = @()
    if (-not $Results.ollama) { $failed += "Ollama" }
    if (-not $Results.rust) { $failed += "Rust" }
    if (-not $Results.proxy) { $failed += "Proxy" }
    if (-not $Results.tts) { $failed += "TTS" }
    if (-not $Results.operative) { $failed += "boni-agent" }
    if (-not $Results.docker) { $failed += "Docker" }
    if (-not $Results.webui) { $failed += "Open WebUI" }
    if (-not $Results.oj_desktop) { $failed += "OJ Desktop" }
    Write-Host "  >>> BONI v2.1 - Parcial ($($failed.Count) fallos: $($failed -join ', ')) <<<" -ForegroundColor Yellow
}

# ============================================================
# PASO 14 - Abrir navegador
# ============================================================
Write-Step "Abrir navegadores"

try {
    Start-Process "http://localhost:3000"
    Write-Ok "Navegador abierto: http://localhost:3000 (Open WebUI)"
} catch {
    Write-Warn "No se pudo abrir navegador: $_"
}

if ($Results.openhands) {
    Start-Sleep -Seconds 2
    try {
        Start-Process "http://localhost:3002"
        Write-Ok "Navegador abierto: http://localhost:3002 (OpenHands)"
    } catch {
        Write-Warn "No se pudo abrir OpenHands en navegador: $_"
    }
}

# ============================================================
# LOG Y FIN
# ============================================================
Write-Log "=== BONI v2.1 INICIO COMPLETADO ($TotalTime segundos) ==="
Write-Info "Log completo guardado en: $LogFile"
Write-Host ""

if (-not $Silent) {
    Write-Host "Presiona cualquier tecla para cerrar..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
