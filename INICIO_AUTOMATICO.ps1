#Requires -Version 5.1
param([switch]$Silent, [int]$JarvisTimeout = 120)

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LogFile = Join-Path $ScriptPath "inicio_auto.log"
$StartTime = Get-Date

$Host.UI.RawUI.WindowTitle = "BONI v2.1 - Inicio Automatico"

function Write-Log  { param([string]$M) $M | Out-File -FilePath $LogFile -Encoding utf8 -Append }
function Write-Step { param([string]$M) Write-Host "--- $M ---" -ForegroundColor White; Write-Log "=== $M ===" }
function Write-Ok   { param([string]$M) Write-Host "  [OK] $M" -ForegroundColor Green; Write-Log "[OK] $M" }
function Write-Warn { param([string]$M) Write-Host "  [WARN] $M" -ForegroundColor Yellow; Write-Log "[WARN] $M" }
function Write-Err  { param([string]$M) Write-Host "  [ERR] $M" -ForegroundColor Red; Write-Log "[ERR] $M" }
function Write-Info { param([string]$M) Write-Host "  [..] $M" -ForegroundColor Cyan; Write-Log "[INFO] $M" }

function Test-Port { param([string]$C="localhost", [int]$P, [int]$T=2000)
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $async = $tcp.BeginConnect($C, $P, $null, $null)
    if ($async.AsyncWaitHandle.WaitOne($T, $false)) { $tcp.EndConnect($async) | Out-Null; $tcp.Close(); return $true }
    else { $tcp.Close(); return $false }
  } catch { return $false }
}

function Invoke-Wsl { param([string]$Command)
  try {
    $tmpFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmpFile -Value $Command -NoNewline -Encoding ASCII
    $result = wsl -d Ubuntu-22.04 -- bash $tmpFile 2>&1
    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    return $result
  } catch { return "" }
}

function Invoke-WslInline { param([string]$Command)
  try {
    $esc = $Command -replace '"', '\"'
    $result = wsl -d Ubuntu-22.04 -- bash -lc "$esc" 2>&1
    if (-not $?) { return "" }
    return $result
  } catch { return "" }
}

if (-not $Silent) {
  Clear-Host
  Write-Host "========================================================" -ForegroundColor Cyan
  Write-Host "       B.O.N.I. v2.1 - Inicio Automatico (Web Chat)" -ForegroundColor Cyan
  Write-Host "========================================================" -ForegroundColor Cyan
  Write-Host "  Inicio: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
  Write-Host "========================================================`n" -ForegroundColor Cyan
}

# ===== 1. OLLAMA (Windows) =====
Write-Step "1/6 - Verificar Ollama (Windows)"
$ollamaOk = $false
if (Test-Port -P 11434) {
  Write-Ok "Ollama ya responde en localhost:11434"
  $ollamaOk = $true
} else {
  Write-Info "Iniciando ollama serve..."
  try { $null = Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden -PassThru } catch { Write-Warn "No se pudo iniciar ollama: $_" }
  $timeout = [datetime]::Now.AddSeconds(30)
  while ([datetime]::Now -lt $timeout) {
    Start-Sleep -Seconds 3
    if (Test-Port -P 11434) { Write-Ok "Ollama conectado"; $ollamaOk = $true; break }
    Write-Info "Esperando Ollama..."
  }
  if (-not $ollamaOk) { Write-Warn "Ollama no responde tras 30s - continuando" }
}

# ===== 2. SANDBOX =====
Write-Step "2/6 - Verificar Sandbox Server"
$sandboxOk = $false
if (Test-Port -P 8765) {
  Write-Ok "Sandbox ya responde en :8765"
  $sandboxOk = $true
} else {
  $sandboxScript = Join-Path $ScriptPath "boni_sandbox_server.py"
  if (Test-Path $sandboxScript) {
    try {
      $null = Start-Process "pythonw" -ArgumentList "`"$sandboxScript`"" -WindowStyle Hidden -PassThru
      Start-Sleep -Seconds 2
      Write-Ok "Sandbox lanzado en :8765"
      $sandboxOk = $true
    } catch { Write-Warn "Error iniciando sandbox: $_" }
  } else { Write-Warn "boni_sandbox_server.py no encontrado" }
}

# ===== 3. GATEWAY IP =====
Write-Step "3/6 - Detectar gateway WSL"
$WIN_GW = ""
for ($i = 1; $i -le 3; $i++) {
  $result = Invoke-Wsl "ip route | grep default | awk '{print `$3}'"
  $result = "$result".Trim()
  if (-not [string]::IsNullOrWhiteSpace($result)) { $WIN_GW = $result; break }
  Start-Sleep -Seconds 3
}
if ([string]::IsNullOrWhiteSpace($WIN_GW)) {
  $WIN_GW = "172.29.176.1"
  Write-Warn "Gateway no detectado, usando fallback $WIN_GW"
} else {
  Write-Ok "Gateway: $WIN_GW"
}

# ===== 4. TTS (WSL) =====
Write-Step "4/6 - Verificar TTS Server (WSL)"
$ttsOk = $false
$ttsHealth = Invoke-Wsl "curl -s --connect-timeout 3 http://localhost:5050/health"
if ($ttsHealth -match "ok") {
  Write-Ok "TTS Server ya responde en WSL:5050"
  $ttsOk = $true
} else {
  Write-Info "Iniciando TTS Server (espeak)..."
  Invoke-Wsl "mkdir -p ~/.boni"
  $ttsCmd = @'
nohup python3 /root/boni_voice/tts_server.py > ~/.boni/tts.log 2>&1 &
'@
  Invoke-Wsl $ttsCmd
  Start-Sleep -Seconds 5
  $check = Invoke-Wsl "curl -s --connect-timeout 5 http://localhost:5050/health"
  if ($check -match "ok") { Write-Ok "TTS Server respondiendo"; $ttsOk = $true }
  else { Write-Warn "TTS podria no estar listo - verificar espeak-ng en WSL" }
}

# ===== 5. OPENJARVIS (WSL) =====
Write-Step "5/6 - Verificar OpenJarvis Server (WSL)"
$jarvisOk = $false
$jarvisHealth = Invoke-Wsl "curl -s --connect-timeout 5 http://127.0.0.1:8000/health"
if (-not [string]::IsNullOrWhiteSpace($jarvisHealth)) {
  Write-Ok "OpenJarvis ya responde en WSL:8000"
  $jarvisOk = $true
} else {
  Write-Info "Configurando IP de Ollama (gateway $WIN_GW)..."
  $configCmd = "jarvis config set engine.ollama.host http://${WIN_GW}:11434"
  Invoke-Wsl $configCmd | Out-Null
  $configCmd2 = "jarvis config set engine.ollama.url http://${WIN_GW}:11434"
  Invoke-Wsl $configCmd2 | Out-Null

  Write-Info "Matando procesos anteriores de OpenJarvis..."
  Invoke-Wsl "pkill -f 'openjarvis.cli' 2>/dev/null; pkill -f 'jarvis serve' 2>/dev/null; sleep 2"

  Write-Info "Iniciando OpenJarvis (cold import ~36s, timeout ${JarvisTimeout}s)..."
  $startCmd = "nohup python3.10 -m openjarvis.cli serve --port 8000 > ~/.boni/jarvis2.log 2>&1 &"
  Invoke-Wsl $startCmd

  $timeout = [datetime]::Now.AddSeconds($JarvisTimeout)
  $attempts = 0
  while ([datetime]::Now -lt $timeout) {
    $attempts++
    Start-Sleep -Seconds 10
    $check = Invoke-Wsl "curl -s --connect-timeout 5 http://127.0.0.1:8000/health"
    if (-not [string]::IsNullOrWhiteSpace($check)) {
      Write-Ok "OpenJarvis responde tras $($attempts * 10)s"
      $jarvisOk = $true
      break
    }
    Write-Info "Esperando OpenJarvis... ($($attempts * 10)s/${JarvisTimeout}s)"
  }
  if (-not $jarvisOk) {
    Write-Warn "OpenJarvis no responde tras ${JarvisTimeout}s"
    $log = Invoke-Wsl "tail -10 ~/.boni/jarvis2.log"
    Write-Info "Ultimas lineas del log:"
    $log -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
  }
}

# ===== 6. PROXY + NAVEGADOR =====
Write-Step "6/6 - Iniciar Proxy + Navegador"
$proxyPath = Join-Path $ScriptPath "boni_proxy.py"
if (Test-Port -P 8080) {
  Write-Ok "Proxy ya responde en :8080"
} else {
  try {
    $null = Start-Process "python" -ArgumentList "`"$proxyPath`"" -WindowStyle Normal -PassThru
    Start-Sleep -Seconds 3
    Write-Ok "Proxy lanzado en :8080"
  } catch { Write-Err "Error iniciando proxy: $_" }
}

try { Start-Process "http://localhost:8080"; Write-Ok "Navegador abierto" } catch { Write-Warn "No se pudo abrir navegador" }

# ===== REPORTE =====
$TotalTime = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 1)
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "  BONI v2.1 - Stack listo en ${TotalTime}s" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Ollama      localhost:11434  $(if($ollamaOk){'OK'}else{'WARN'})" -ForegroundColor $(if($ollamaOk){'Green'}else{'Yellow'})
Write-Host "  Sandbox     localhost:8765   $(if($sandboxOk){'OK'}else{'WARN'})" -ForegroundColor $(if($sandboxOk){'Green'}else{'Yellow'})
Write-Host "  TTS         WSL:5050         $(if($ttsOk){'OK'}else{'WARN'})" -ForegroundColor $(if($ttsOk){'Green'}else{'Yellow'})
Write-Host "  OpenJarvis  WSL:8000         $(if($jarvisOk){'OK'}else{'WARN'})" -ForegroundColor $(if($jarvisOk){'Green'}else{'Yellow'})
Write-Host "  Proxy       localhost:8080   $(if(Test-Port -P 8080){'OK'}else{'WARN'})" -ForegroundColor $(if(Test-Port -P 8080){'Green'}else{'Yellow'})
Write-Host "  Web Chat    http://localhost:8080" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log: $LogFile" -ForegroundColor Gray

if (-not $Silent) {
  Write-Host "`nPresiona Enter para cerrar..." -ForegroundColor Gray
  $null = Read-Host
}
