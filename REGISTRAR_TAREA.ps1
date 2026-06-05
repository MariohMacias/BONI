<#
.SYNOPSIS
  Registra BONI_INICIO.ps1 como tarea programada al iniciar sesion.
.DESCRIPTION
  Crea tarea "BONI Inicio Automatico" que corre BONI_INICIO.ps1
  al iniciar sesion con privilegios de administrador.
  Ejecutar UNA VEZ para activar el inicio automatico.
#>

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PS1_PATH = Join-Path $SCRIPT_DIR "BONI_INICIO.ps1"
$TASK_NAME = "BONI Inicio Automatico"

Write-Host "=== Registrando tarea programada: $TASK_NAME ===" -ForegroundColor Cyan
Write-Host ""

# Verificar que el script PS1 existe
if (-not (Test-Path $PS1_PATH)) {
    Write-Host "[FAIL] No se encuentra: $PS1_PATH" -ForegroundColor Red
    Write-Host "Asegurate de que BONI_INICIO.ps1 esta en el mismo directorio." -ForegroundColor Yellow
    exit 1
}

# Crear accion
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$PS1_PATH`""

# Crear disparador (al iniciar sesion)
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "nosoy"

# Crear configuraciones
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable $true `
    -AllowStartIfOnBatteries $true

# Crear principal (usuario con privilegios)
$principal = New-ScheduledTaskPrincipal `
    -UserId "nosoy" `
    -RunLevel Highest

# Registrar tarea
try {
    Register-ScheduledTask `
        -TaskName $TASK_NAME `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Force -ErrorAction Stop

    Write-Host "[OK] Tarea '$TASK_NAME' registrada exitosamente!" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] Error al registrar tarea: $_" -ForegroundColor Red
    Write-Host "Ejecuta este script como Administrador." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Verificar
$task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "Detalles de la tarea:" -ForegroundColor Cyan
    Write-Host "  Nombre:     $($task.TaskName)" -ForegroundColor White
    Write-Host "  Estado:     $($task.State)" -ForegroundColor White
    Write-Host "  Usuario:    $($task.Principal.UserId)" -ForegroundColor White
    Write-Host "  Ejecutable: PowerShell.exe" -ForegroundColor White
    Write-Host "  Disparador: Al iniciar sesion (nosoy)" -ForegroundColor White
    Write-Host "  Timeout:    10 minutos" -ForegroundColor White
    Write-Host "  Reintentos: 2 (cada 2 min)" -ForegroundColor White
    Write-Host ""
    Write-Host "[OK] Tarea verificada. BONI iniciara automaticamente al iniciar sesion." -ForegroundColor Green
} else {
    Write-Host "[FAIL] No se pudo verificar la tarea." -ForegroundColor Red
}

Write-Host ""
Write-Host "Para eliminar la tarea en el futuro:" -ForegroundColor Yellow
Write-Host "  Unregister-ScheduledTask -TaskName '$TASK_NAME' -Confirm:`$false" -ForegroundColor Gray
