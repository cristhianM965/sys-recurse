# lib/30-iis-site.ps1
#requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

function New-OrUpdate-IISFTPSite {
  Core-Banner "4) Sitio IIS FTP + Auth + User Isolation + Reglas FTP"

  Import-Module WebAdministration

  # Parar FTP para evitar locks mientras tocamos config
  try { Stop-Service ftpsvc -Force -ErrorAction SilentlyContinue } catch {}
  Start-Sleep -Seconds 1

  # Desbloquear secciones para permitir config a nivel sitio (evita overrideModeDefault="Deny")
  $appcmd = Join-Path $env:windir "System32\inetsrv\appcmd.exe"
  & $appcmd unlock config /section:system.ftpServer/security/authorization | Out-Null
  & $appcmd unlock config /section:system.ftpServer/security/authentication/anonymousAuthentication | Out-Null
  & $appcmd unlock config /section:system.ftpServer/security/authentication/basicAuthentication | Out-Null

  # Crear sitio si no existe
  $sitePath = "IIS:\Sites\$($Global:FTP_SITE_NAME)"
  if (-not (Test-Path $sitePath)) {
    New-WebFtpSite -Name $Global:FTP_SITE_NAME -Port $Global:FTP_PORT -PhysicalPath $Global:T5_SITE_ROOT -Force | Out-Null
    Core-Log "Sitio FTP creado: $($Global:FTP_SITE_NAME)"
  } else {
    Core-Log "Sitio FTP ya existe: $($Global:FTP_SITE_NAME)"
  }

  # Habilitar autenticación
  Set-ItemProperty "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
  Set-ItemProperty "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true

  # User Isolation: IsolateUsers -> <siteRoot>\LocalUser\<username>\
  Set-ItemProperty "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Name ftpServer.userIsolation.mode -Value 2

  # Reinicio corto para liberar locks en config (si aplica)
  iisreset /stop | Out-Null
  Start-Sleep -Seconds 2
  iisreset /start | Out-Null
  Start-Sleep -Seconds 2

  # --- Reglas de autorización FTP (idempotente, sin Clear-WebConfiguration) ---
  $filter = "system.ftpServer/security/authorization"
  $psPath = "IIS:\Sites\$($Global:FTP_SITE_NAME)"

  # Remover reglas existentes por índice hasta dejar vacío
  while ($true) {
    $list = Get-WebConfiguration -PSPath $psPath -Filter "$filter/add" -ErrorAction SilentlyContinue
    if (-not $list) { break }
    try {
      Remove-WebConfigurationProperty -PSPath $psPath -Filter $filter -Name "." -AtIndex 0 -ErrorAction SilentlyContinue | Out-Null
    } catch {
      break
    }
    Start-Sleep -Milliseconds 150
  }

  # 1) Anónimo: SOLO lectura
  Add-WebConfiguration -PSPath $psPath -Filter $filter -Value @{
    accessType  = "Allow"
    users       = "anonymous"
    permissions = "Read"
  } | Out-Null

  # 2) Autenticados: lectura + escritura
  Add-WebConfiguration -PSPath $psPath -Filter $filter -Value @{
    accessType  = "Allow"
    users       = "*"
    permissions = "Read,Write"
  } | Out-Null

  # Levantar FTP
  try { Start-Service ftpsvc -ErrorAction SilentlyContinue } catch {}

  Core-Log "Auth + Isolation + Authorization configurado (unlock aplicado)"
}