#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IPv4 {
  param([Parameter(Mandatory)][string]$Ip)
  $pattern = '^(\d{1,3}\.){3}\d{1,3}$'
  if ($Ip -notmatch $pattern) { return $false }
  $parts = $Ip.Split('.')
  foreach ($p in $parts) {
    if ([int]$p -lt 0 -or [int]$p -gt 255) { return $false }
  }
  return $true
}

function Read-IPv4 {
  param([Parameter(Mandatory)][string]$Prompt)
  while ($true) {
    $v = Read-Host $Prompt
    if (Test-IPv4 $v) { return $v }
    Write-Host "  -> IPv4 inválida. Ejemplo: 192.168.100.1" -ForegroundColor Yellow
  }
}

function Read-NonEmpty {
  param([Parameter(Mandatory)][string]$Prompt)
  while ($true) {
    $v = Read-Host $Prompt
    if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
    Write-Host "  -> No puede ir vacío." -ForegroundColor Yellow
  }
}

function Read-IntRange {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][int]$Min,
    [Parameter(Mandatory)][int]$Max
  )
  while ($true) {
    $v = Read-Host "$Prompt ($Min-$Max)"
    if ($v -match '^\d+$') {
      $n = [int]$v
      if ($n -ge $Min -and $n -le $Max) { return $n }
    }
    Write-Host "  -> Número inválido." -ForegroundColor Yellow
  }
}

function Install-DhcpRole-Idempotent {
  $feature = Get-WindowsFeature -Name DHCP
  if ($feature.Installed) {
    Write-Host "[OK] Rol DHCP ya está instalado."
  } else {
    Write-Host "[INFO] Instalando Rol DHCP Server..."
    Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
    Write-Host "[OK] Instalación completa."
  }
}

function Ensure-DhcpServiceRunning {
  $svc = Get-Service -Name "DHCPServer"
  if ($svc.Status -ne "Running") {
    Start-Service -Name "DHCPServer"
  }
  Set-Service -Name "DHCPServer" -StartupType Automatic
  Write-Host "[OK] Servicio DHCPServer en ejecución."
}

function Ensure-Scope {
  param(
    [Parameter(Mandatory)][string]$ScopeName,
    [Parameter(Mandatory)][string]$StartRange,
    [Parameter(Mandatory)][string]$EndRange,
    [Parameter(Mandatory)][string]$SubnetMask,
    [Parameter(Mandatory)][int]$LeaseMinutes,
    [Parameter(Mandatory)][string]$Gateway,
    [Parameter(Mandatory)][string]$DnsServer
  )

  # Derivar NetworkID (simple): 192.168.100.0 desde StartRange
  $oct = $StartRange.Split('.')
  $networkId = "$($oct[0]).$($oct[1]).$($oct[2]).0"

  $existing = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.ScopeId -eq $networkId }

  if (-not $existing) {
    Write-Host "[INFO] Creando Scope IPv4 $networkId ..."
    Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartRange -EndRange $EndRange -SubnetMask $SubnetMask -State Active | Out-Null
    Write-Host "[OK] Scope creado."
  }
  else {
    Write-Host "[OK] Scope ya existe ($networkId). No se recrea."
  }

  # Lease duration
  $lease = New-TimeSpan -Minutes $LeaseMinutes
  Set-DhcpServerv4Scope -ScopeId $networkId -LeaseDuration $lease | Out-Null
  Write-Host "[OK] Lease configurado: $LeaseMinutes minutos."

  # Options
  Set-DhcpServerv4OptionValue -ScopeId $networkId -Router $Gateway -DnsServer $DnsServer | Out-Null
  Write-Host "[OK] Opciones configuradas: Gateway=$Gateway DNS=$DnsServer"
}

function Monitor-Menu {
  while ($true) {
    Write-Host ""
    Write-Host "===== MONITOREO DHCP (Windows) ====="
    Write-Host "1) Ver estado del servicio"
    Write-Host "2) Listar leases activas"
    Write-Host "3) Salir"
    $opt = Read-Host "Opción"

    switch ($opt) {
      "1" {
        Get-Service -Name DHCPServer | Format-List Status, Name, StartType
      }
      "2" {
        # Muestra todas las concesiones (si quieres por scope, filtra por -ScopeId)
        Get-DhcpServerv4Lease | Sort-Object LeaseExpiryTime | Select-Object IPAddress, ClientId, HostName, AddressState, LeaseExpiryTime | Format-Table -AutoSize
      }
      "3" { break }
      default { Write-Host "Opción inválida." -ForegroundColor Yellow }
    }
  }
}

# =========================
# MAIN
# =========================
Install-DhcpRole-Idempotent
Ensure-DhcpServiceRunning

Write-Host ""
Write-Host "===== CONFIGURACIÓN DHCP (Windows) ====="

$scopeName   = Read-NonEmpty "Nombre descriptivo del Scope"
$startRange  = Read-IPv4 "Rango inicial (ej. 192.168.100.50)"
$endRange    = Read-IPv4 "Rango final (ej. 192.168.100.150)"

$subnetMask  = Read-Host "Subnet Mask (default 255.255.255.0)"
if ([string]::IsNullOrWhiteSpace($subnetMask)) { $subnetMask = "255.255.255.0" }
while (-not (Test-IPv4 $subnetMask)) {
  Write-Host "  -> IPv4 inválida." -ForegroundColor Yellow
  $subnetMask = Read-Host "Subnet Mask"
}

$leaseMin = Read-IntRange "Lease Time en minutos" 1 10080
$gateway  = Read-IPv4 "Gateway/Router (ej. 192.168.100.1)"
$dns      = Read-IPv4 "DNS (IP del servidor DNS de la práctica 1)"

Ensure-Scope -ScopeName $scopeName -StartRange $startRange -EndRange $endRange -SubnetMask $subnetMask -LeaseMinutes $leaseMin -Gateway $gateway -DnsServer $dns

Write-Host ""
Write-Host "[DONE] DHCP configurado en Windows."
Monitor-Menu
