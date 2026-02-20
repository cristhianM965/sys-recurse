param(
  [Parameter(Mandatory=$true)]
  [string]$TargetIP,          # IP del cliente/VM a la que apuntan los registros

  [Parameter(Mandatory=$true)]
  [string]$ServerIP,          # IP del servidor DNS (esta VM)

  [string]$Domain = "reprobados.com",

  [ValidateSet("A","CNAME")]
  [string]$WwwMode = "CNAME", # www como CNAME a @ o como A directo

  [switch]$SetStaticIP,       # Si se pasa, verifica y si no hay fija, la configura

  [string]$InterfaceAlias = "" # Alias de la NIC (si no, auto)
)

function Log($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m){ throw $m }

function Get-PrimaryInterface {
  $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.HardwareInterface -eq $true }
  if ($adapters.Count -eq 0) { Fail "No se encontró NIC activa." }
  return $adapters[0].Name
}

function Has-StaticIP($ifName){
  $ip = Get-NetIPConfiguration -InterfaceAlias $ifName
  # Si IPv4Address tiene PrefixOrigin "Manual" -> estática
  return ($ip.IPv4Address.PrefixOrigin -contains "Manual")
}

function Configure-StaticIP($ifName){
  $ipCidr = Read-Host "IP/CIDR para el servidor (ej. 192.168.100.20/24)"
  $gw     = Read-Host "Gateway (ej. 192.168.100.1)"
  $dns    = Read-Host "DNS upstream (ej. 8.8.8.8 o tu DNS anterior)"

  $ipParts = $ipCidr.Split("/")
  $ipAddr  = $ipParts[0]
  $prefix  = [int]$ipParts[1]

  Log "Aplicando IP fija en '$ifName' -> $ipAddr/$prefix (GW $gw, DNS $dns)"

  # Limpia IPv4 anteriores (evita conflicto)
  Get-NetIPAddress -InterfaceAlias $ifName -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

  New-NetIPAddress -InterfaceAlias $ifName -IPAddress $ipAddr -PrefixLength $prefix -DefaultGateway $gw
  Set-DnsClientServerAddress -InterfaceAlias $ifName -ServerAddresses $dns
}

# 1) Verificación IP fija
if ($SetStaticIP) {
  if ([string]::IsNullOrWhiteSpace($InterfaceAlias)) {
    $InterfaceAlias = Get-PrimaryInterface
  }
  if (Has-StaticIP $InterfaceAlias) {
    Log "IP fija detectada en $InterfaceAlias (OK)."
  } else {
    Warn "No se detectó IP fija en $InterfaceAlias."
    Configure-StaticIP $InterfaceAlias
  }
}

# 2) Instalación / Idempotencia del rol DNS
$dnsFeature = Get-WindowsFeature DNS
if (-not $dnsFeature.Installed) {
  Log "Instalando rol DNS..."
  Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
} else {
  Log "Rol DNS ya instalado (idempotente)."
}

# 3) Zona primaria / Idempotencia
$zone = Get-DnsServerZone -Name $Domain -ErrorAction SilentlyContinue
if (-not $zone) {
  Log "Creando zona primaria: $Domain"
  Add-DnsServerPrimaryZone -Name $Domain -ZoneFile "$Domain.dns" -DynamicUpdate None
} else {
  Log "Zona $Domain ya existe (idempotente)."
}

# 4) Registros
# Root A (@)
$rootA = Get-DnsServerResourceRecord -ZoneName $Domain -Name "@" -RRType "A" -ErrorAction SilentlyContinue
if ($rootA) {
  Log "Actualizando A (@) -> $TargetIP"
  $newRec = $rootA.Clone()
  $newRec.RecordData.IPv4Address = [System.Net.IPAddress]::Parse($TargetIP)
  Set-DnsServerResourceRecord -ZoneName $Domain -OldInputObject $rootA -NewInputObject $newRec -PassThru | Out-Null
} else {
  Log "Creando A (@) -> $TargetIP"
  Add-DnsServerResourceRecordA -ZoneName $Domain -Name "@" -IPv4Address $TargetIP
}

# www
if ($WwwMode -eq "CNAME") {
  # elimina www A si existe, crea/actualiza CNAME
  $wwwA = Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "A" -ErrorAction SilentlyContinue
  if ($wwwA) { Remove-DnsServerResourceRecord -ZoneName $Domain -RRType "A" -Name "www" -RecordData $wwwA.RecordData -Force }

  $wwwC = Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "CNAME" -ErrorAction SilentlyContinue
  if ($wwwC) {
    Log "www ya es CNAME (idempotente)."
  } else {
    Log "Creando CNAME www -> @"
    Add-DnsServerResourceRecordCName -ZoneName $Domain -Name "www" -HostNameAlias "$Domain"
  }
} else {
  # elimina CNAME si existe, crea/actualiza A
  $wwwC = Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "CNAME" -ErrorAction SilentlyContinue
  if ($wwwC) { Remove-DnsServerResourceRecord -ZoneName $Domain -RRType "CNAME" -Name "www" -RecordData $wwwC.RecordData -Force }

  $wwwA = Get-DnsServerResourceRecord -ZoneName $Domain -Name "www" -RRType "A" -ErrorAction SilentlyContinue
  if ($wwwA) {
    Log "Actualizando A (www) -> $TargetIP"
    $newRec = $wwwA.Clone()
    $newRec.RecordData.IPv4Address = [System.Net.IPAddress]::Parse($TargetIP)
    Set-DnsServerResourceRecord -ZoneName $Domain -OldInputObject $wwwA -NewInputObject $newRec -PassThru | Out-Null
  } else {
    Log "Creando A (www) -> $TargetIP"
    Add-DnsServerResourceRecordA -ZoneName $Domain -Name "www" -IPv4Address $TargetIP
  }
}

# 5) Servicio
$svc = Get-Service -Name DNS -ErrorAction SilentlyContinue
if ($svc.Status -ne "Running") {
  Log "Iniciando servicio DNS..."
  Start-Service DNS
}
Log "DNS Server listo. Pruebas sugeridas (cliente): nslookup $Domain $ServerIP / ping www.$Domain"
