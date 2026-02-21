function Ensure-OpenSSHServerAndFirewall {
  Require-Admin

  Write-Info "Buscando capability OpenSSH.Server..."
  $cap = Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH.Server*"
  if ($null -eq $cap) { throw "No se encontró OpenSSH.Server capability." }

  if ($cap.State -ne "Installed") {
    Write-Info "Instalando OpenSSH Server..."
    Add-WindowsCapability -Online -Name $cap.Name | Out-Null
  } else {
    Write-Info "OpenSSH Server ya instalado."
  }

  Write-Info "Habilitando e iniciando servicio sshd..."
  Set-Service -Name sshd -StartupType Automatic
  Start-Service sshd

  Write-Info "Regla de Firewall TCP/22..."
  $ruleName = "OpenSSH-Server-In-TCP-22"
  if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22 | Out-Null
    Write-Info "Regla creada: $ruleName"
  } else {
    Write-Info "Regla ya existe: $ruleName"
  }

  Write-Info "Validación rápida:"
  Get-Service sshd | Format-Table Status, Name, StartType
  netstat -ano | findstr ":22" | Out-Host
}