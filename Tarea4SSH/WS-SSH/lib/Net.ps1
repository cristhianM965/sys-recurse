function Read-NonEmpty($prompt, $default = $null) {
  $v = Read-Host $prompt
  if ([string]::IsNullOrWhiteSpace($v)) { return $default }
  return $v
}

function Test-IPv4($ip) {
  return [System.Net.IPAddress]::TryParse($ip, [ref]([System.Net.IPAddress]$null)) -and ($ip -match '^\d{1,3}(\.\d{1,3}){3}$')
}

function Test-Prefix($p) {
  if ($p -match '^\d+$') {
    $n = [int]$p
    return ($n -ge 0 -and $n -le 32)
  }
  return $false
}

function Choose-Adapter {
  $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Sort-Object -Property Name
  if (-not $adapters) { throw "No hay adaptadores activos (Up)." }

  Write-Host "`nAdaptadores disponibles (Up):"
  $i = 1
  foreach ($a in $adapters) {
    $ip = (Get-NetIPAddress -InterfaceIndex $a.IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    Write-Host ("[{0}] {1}  (IPv4: {2})" -f $i, $a.Name, ($ip ?? "Sin IPv4"))
    $i++
  }

  $choice = Read-Host "Elige número del adaptador para configurar IP estática (ej. 2)"
  if (-not ($choice -match '^\d+$')) { throw "Selección inválida." }
  $idx = [int]$choice
  if ($idx -lt 1 -or $idx -gt $adapters.Count) { throw "Selección fuera de rango." }

  return $adapters[$idx-1]
}

function Set-StaticIPv4Interactive {
  Require-Admin

  $adapter = Choose-Adapter
  Write-Info "Seleccionado: $($adapter.Name)"

  # Datos
  $ip = Read-NonEmpty "IPv4 estática (ej. 192.168.100.20)" $null
  while (-not (Test-IPv4 $ip)) {
    Write-Warn "IPv4 inválida."
    $ip = Read-NonEmpty "IPv4 estática" $null
  }

  $prefix = Read-NonEmpty "PrefixLength (ej. 24)" "24"
  while (-not (Test-Prefix $prefix)) {
    Write-Warn "Prefijo inválido (0-32)."
    $prefix = Read-NonEmpty "PrefixLength" "24"
  }
  $prefix = [int]$prefix

  # Gateway es opcional (en red interna normalmente VACÍO)
  $gw = Read-Host "Gateway (deja vacío si es Red Interna)"
  if (-not [string]::IsNullOrWhiteSpace($gw)) {
    while (-not (Test-IPv4 $gw)) {
      Write-Warn "Gateway inválido."
      $gw = Read-Host "Gateway (o vacío)"
      if ([string]::IsNullOrWhiteSpace($gw)) { break }
    }
  } else {
    $gw = $null
  }

  # DNS opcional (si quieres resolución en Windows; si es red interna, puedes poner tu DNS del lab o 8.8.8.8)
  $dns1 = Read-Host "DNS1 (opcional, ej. 8.8.8.8 o IP de tu DNS)"
  if (-not [string]::IsNullOrWhiteSpace($dns1)) {
    while (-not (Test-IPv4 $dns1)) {
      Write-Warn "DNS1 inválido."
      $dns1 = Read-Host "DNS1 (o vacío)"
      if ([string]::IsNullOrWhiteSpace($dns1)) { break }
    }
  } else { $dns1 = $null }

  $dns2 = Read-Host "DNS2 (opcional)"
  if (-not [string]::IsNullOrWhiteSpace($dns2)) {
    while (-not (Test-IPv4 $dns2)) {
      Write-Warn "DNS2 inválido."
      $dns2 = Read-Host "DNS2 (o vacío)"
      if ([string]::IsNullOrWhiteSpace($dns2)) { break }
    }
  } else { $dns2 = $null }

  # Limpieza de IPv4 previas en ese adaptador (para evitar duplicados)
  Write-Info "Eliminando IPv4 anteriores del adaptador (si existen)..."
  Get-NetIPAddress -InterfaceIndex $adapter.IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -ne "127.0.0.1" } |
    ForEach-Object {
      try { Remove-NetIPAddress -InterfaceIndex $adapter.IfIndex -IPAddress $_.IPAddress -Confirm:$false -ErrorAction Stop }
      catch { Write-Warn "No se pudo quitar $_.IPAddress (puede estar en uso): $($_.Exception.Message)" }
    }

  Write-Info "Asignando IPv4 estática..."
  if ($gw) {
    New-NetIPAddress -InterfaceIndex $adapter.IfIndex -IPAddress $ip -PrefixLength $prefix -DefaultGateway $gw | Out-Null
  } else {
    New-NetIPAddress -InterfaceIndex $adapter.IfIndex -IPAddress $ip -PrefixLength $prefix | Out-Null
  }

  if ($dns1 -or $dns2) {
    $dnsList = @()
    if ($dns1) { $dnsList += $dns1 }
    if ($dns2) { $dnsList += $dns2 }
    Write-Info "Configurando DNS: $($dnsList -join ', ')"
    Set-DnsClientServerAddress -InterfaceIndex $adapter.IfIndex -ServerAddresses $dnsList
  } else {
    Write-Info "DNS no configurado (sin cambios)."
  }

  Write-Info "Resumen final (ipconfig):"
  ipconfig | Out-Host
}