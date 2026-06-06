<#
.SYNOPSIS
  Registra BONI_INICIO.ps1 como tarea programada al iniciar sesion.
.DESCRIPTION
  Crea tarea "BONI Inicio Automatico" que corre BONI_INICIO.ps1
  al iniciar sesion con privilegios de administrador y retraso de 30s.
  Ejecutar UNA VEZ como administrador para activar el inicio automatico.
#>

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PS1_PATH = Join-Path $SCRIPT_DIR "BONI_INICIO.ps1"
$TASK_NAME = "BONI Inicio Automatico"

Write-Host "=== Registrando tarea programada: $TASK_NAME ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $PS1_PATH)) {
    Write-Host "[FAIL] No se encuentra: $PS1_PATH" -ForegroundColor Red
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$PS1_PATH`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User "nosoy"
$trigger.Delay = "PT30S"

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 3) `
    -StartWhenAvailable $true `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId "nosoy" `
    -RunLevel Highest

try {
    Register-ScheduledTask `
        -TaskName $TASK_NAME `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Inicia el stack completo de BONI v2.1 al encender la PC" `
        -Force -ErrorAction Stop

    Write-Host "[OK] Tarea '$TASK_NAME' registrada exitosamente!" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Error al registrar tarea: $_" -ForegroundColor Red
    Write-Host "Ejecuta este script como Administrador." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

$task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "Detalles de la tarea:" -ForegroundColor Cyan
    Write-Host "  Nombre:       $($task.TaskName)" -ForegroundColor White
    Write-Host "  Estado:       $($task.State)" -ForegroundColor White
    Write-Host "  Usuario:      $($task.Principal.UserId)" -ForegroundColor White
    Write-Host "  Ejecutable:   PowerShell.exe" -ForegroundColor White
    Write-Host "  Disparador:   Al iniciar sesion (nosoy)" -ForegroundColor White
    Write-Host "  Retraso:      30 segundos" -ForegroundColor White
    Write-Host "  Timeout:      15 minutos" -ForegroundColor White
    Write-Host "  Reintentos:   2 (cada 3 min)" -ForegroundColor White
    Write-Host ""
    Write-Host "[OK] Tarea registrada. BONI iniciara automaticamente 30s despues del login." -ForegroundColor Green
} else {
    Write-Host "[FAIL] No se pudo verificar la tarea." -ForegroundColor Red
}

Write-Host ""
Write-Host "Para eliminar la tarea en el futuro:" -ForegroundColor Yellow
Write-Host "  Unregister-ScheduledTask -TaskName '$TASK_NAME' -Confirm:`$false" -ForegroundColor Gray
Write-Host "Para probar la ejecucion manual:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$TASK_NAME'" -ForegroundColor Gray
