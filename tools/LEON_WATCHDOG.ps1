param(
    [int]$PollIntervalSec = 30,
    [int]$RecoveryIntervalMin = 30
)

$ErrorLog = "$env:USERPROFILE\.leon\profiles\just-me\logs\errors.log"
$WatchLog = "$env:USERPROFILE\.leon\profiles\just-me\logs\watchdog.log"
$StateFile = "$env:USERPROFILE\.leon\profiles\just-me\.watchdog_state"

$OpenRouterModel = "openrouter nvidia/nemotron-3-super-120b-a12b:free"
$LocalModel = "openai qwen2.5:0.5b"
$LocalServerUrl = "http://127.0.0.1:8080/v1/models"
$LeonApi = "http://localhost:5366/api/v1/command"

$OpenRouterTestFile = "$env:TEMP\or_watchdog_test.json"
$OpenRouterTestJson = @{model="nvidia/nemotron-3-super-120b-a12b:free"; messages=@(@{role="user"; content="hi"})} | ConvertTo-Json -Compress

try {
    $ApiKey = (Get-Content "$env:USERPROFILE\.leon\profiles\just-me\.env" -Encoding UTF8 | Select-String "LEON_OPENROUTER_API_KEY=(.*)").Matches.Groups[1].Value
} catch {
    $ApiKey = ""
}

function Write-Log {
    param([string]$Msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Msg"
    Add-Content -Path $WatchLog -Value $line -Encoding UTF8
}

function Get-LastErrorPosition {
    if (Test-Path $StateFile) {
        return (Get-Content $StateFile -Raw) -as [int]
    }
    return 0
}

function Set-LastErrorPosition {
    param([int]$Pos)
    Set-Content -Path $StateFile -Value $Pos -NoNewline
}

function Switch-Model {
    param([string]$ModelInput)
    $body = @{mode="execute"; input=$ModelInput} | ConvertTo-Json -Compress
    try {
        $resp = Invoke-RestMethod -Uri $LeonApi -Method Post -Body $body -ContentType "application/json" -TimeoutSec 15
        if ($resp.success) {
            Write-Log "Modelo cambiado a: $ModelInput"
            return $true
        } else {
            Write-Log "Fallo al cambiar modelo: $($resp.message)"
            return $false
        }
    } catch {
        Write-Log "Error conectando a Leon: $($_.Exception.Message)"
        return $false
    }
}

function Test-OpenRouterAvailable {
    try {
        Set-Content -Path $OpenRouterTestFile -Value $OpenRouterTestJson -Encoding ASCII -NoNewline
        $resp = curl.exe -s -X POST "https://openrouter.ai/api/v1/chat/completions" `
            -H "Authorization: Bearer $ApiKey" `
            -H "Content-Type: application/json" `
            -d "@$OpenRouterTestFile" 2>&1
        if ($resp -match '"id"') {
            return $true
        }
        if ($resp -match "429|rate limit|quota|insufficient_quota|credits insufficient|Input must have at least 1 token") {
            Write-Log "OpenRouter aun sin cuota: $($resp.Substring(0, [Math]::Min(200, $resp.Length)))"
        }
        return $false
    } catch {
        return $false
    }
}

function Test-LocalAvailable {
    try {
        $resp = Invoke-WebRequest -Uri $LocalServerUrl -Method Get -TimeoutSec 5 -UseBasicParsing
        return ($resp.StatusCode -eq 200)
    } catch {
        return $false
    }
}

$lastPos = Get-LastErrorPosition
$lastRecoveryCheck = [DateTime]::MinValue
$onFallback = $false

Write-Log "=== Watchdog v2 (GPU) iniciado ==="
Write-Log "PollInterval=${PollIntervalSec}s, RecoveryInterval=${RecoveryIntervalMin}min"
Write-Log "Estado inicial: OpenRouter (default)"
Write-Log "Fallback local: Qwen2.5 1.5B via llama.cpp Vulkan (127.0.0.1:8080)"
Write-Log "API key presente: $($ApiKey.Length -gt 10)"

while ($true) {
    if (Test-Path $ErrorLog) {
        $currentLen = (Get-Item $ErrorLog -ErrorAction SilentlyContinue).Length
        if ($currentLen -and $currentLen -ge 0) {
            if ($currentLen -lt $lastPos) {
                $lastPos = 0
            }
            if ($currentLen -gt $lastPos) {
                try {
                    $fs = New-Object System.IO.FileStream($ErrorLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    $reader = New-Object System.IO.StreamReader($fs)
                    $reader.BaseStream.Seek($lastPos, [System.IO.SeekOrigin]::Begin) | Out-Null
                    $newContent = $reader.ReadToEnd()
                    $reader.Close()
                    $fs.Close()
                } catch {
                    Write-Log "Error leyendo log: $($_.Exception.Message)"
                    $newContent = ""
                }
                $lastPos = $currentLen
                Set-LastErrorPosition $lastPos

                if (-not $onFallback -and $newContent -match "(429|rate limit|quota|Input must have at least 1 token|unavailable for free|insufficient_quota|credits insufficient)") {
                    Write-Log "Detectado error de OpenRouter en log. Cambiando a GPU local..."
                    if (Test-LocalAvailable) {
                        $ok = Switch-Model "/model $LocalModel"
                        if ($ok) {
                            $onFallback = $true
                            $lastRecoveryCheck = Get-Date
                            Write-Log "Fallback a GPU local activado (Qwen2.5 1.5B)"
                        }
                    } else {
                        Write-Log "GPU local no disponible, reintentando mas tarde"
                    }
                }
            }
        }
    }

    if ($onFallback) {
        $nextCheck = $lastRecoveryCheck.AddMinutes($RecoveryIntervalMin)
        if ((Get-Date) -gt $nextCheck) {
            Write-Log "Verificando si OpenRouter recupero cuota..."
            if (Test-OpenRouterAvailable) {
                $ok = Switch-Model "/model $OpenRouterModel"
                if ($ok) {
                    $onFallback = $false
                    Write-Log "OpenRouter recuperado, volviendo a cloud"
                }
            } else {
                Write-Log "OpenRouter aun no disponible"
            }
            $lastRecoveryCheck = Get-Date
        }
    }

    Start-Sleep -Seconds $PollIntervalSec
}
