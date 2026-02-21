$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\lib\Core.ps1"
. "$ScriptDir\lib\Net.ps1"
. "$ScriptDir\lib\SSH.ps1"

function Show-Menu {
  Clear-Host
  Write-Host "=== TAREA 4 - SSH (WINDOWS) ==="
  Write-Host "1) Configurar IP estática (elige adaptador)"
  Write-Host "2) Instalar/Habilitar OpenSSH Server + Firewall 22"
  Write-Host "0) Salir"
  $opt = Read-Host "Opción"

  switch ($opt) {
    "1" { Set-StaticIPv4Interactive; Pause-Console }
    "2" { Ensure-OpenSSHServerAndFirewall; Pause-Console }
    "0" { exit }
    default { Write-Warn "Opción inválida"; Pause-Console }
  }
}

while ($true) { Show-Menu }