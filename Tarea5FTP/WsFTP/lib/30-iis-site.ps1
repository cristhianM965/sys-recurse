function New-OrUpdate-IISFTPSite {
  Core-Banner "4) Sitio IIS FTP + Auth + User Isolation + Reglas FTP"

  Import-Module WebAdministration

  # Crear sitio si no existe
  $sitePath = "IIS:\Sites\$($Global:FTP_SITE_NAME)"
  if(-not (Test-Path $sitePath)){
    New-WebFtpSite -Name $Global:FTP_SITE_NAME -Port $Global:FTP_PORT -PhysicalPath $Global:T5_SITE_ROOT -Force | Out-Null
    Core-Log "Sitio FTP creado: $($Global:FTP_SITE_NAME)"
  } else {
    Core-Log "Sitio FTP ya existe: $($Global:FTP_SITE_NAME)"
  }

  # Habilitar autenticación
  Set-ItemProperty "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
  Set-ItemProperty "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true

  # User Isolation: IsolateUsers (usa carpeta LocalUser\%USERNAME% bajo el site root)
  # Nota: IIS espera la estructura: <siteRoot>\LocalUser\<username>\...
  Set-ItemProperty "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Name ftpServer.userIsolation.mode -Value 2  # 2 = IsolateUsers

  # Evitar bloqueo de applicationHost.config
  iisreset /stop | Out-Null
  Start-Sleep -Seconds 2
  iisreset /start | Out-Null
  Start-Sleep -Seconds 2

  # --- Reglas de autorización FTP ---
  # Limpiar reglas existentes (idempotente)
# Eliminar reglas existentes sin Clear-WebConfiguration (evita locks)
$filter = "system.ftpServer/security/authorization"
$psPath = "IIS:\Sites\$($Global:FTP_SITE_NAME)"

# Remueve todas las reglas existentes
while ($true) {
  $current = Get-WebConfiguration -PSPath $psPath -Filter "$filter/add" -ErrorAction SilentlyContinue
  if (-not $current) { break }

  # Quita la primera regla encontrada (loop hasta que no haya)
  Remove-WebConfigurationProperty -PSPath $psPath -Filter $filter -Name "." -AtElement @{users=$current.users;roles=$current.roles;permissions=$current.permissions;accessType=$current.accessType} -ErrorAction SilentlyContinue
  # Si no coincide exacto, intenta remover por índice
  try { Remove-WebConfigurationProperty -PSPath $psPath -Filter $filter -Name "." -AtIndex 0 -ErrorAction SilentlyContinue } catch {}
  Start-Sleep -Milliseconds 200
}
  # 1) Anónimo: SOLO lectura (a nivel sitio). Como solo verá /general, está OK.
  Add-WebConfiguration -PSPath "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Filter "system.ftpServer/security/authorization" -Value @{
    accessType="Allow"; users="anonymous"; permissions="Read"
  } | Out-Null

  # 2) Autenticados: permitir RW para usuarios locales (a nivel sitio)
  Add-WebConfiguration -PSPath "IIS:\Sites\$($Global:FTP_SITE_NAME)" -Filter "system.ftpServer/security/authorization" -Value @{
    accessType="Allow"; users="*"; permissions="Read,Write"
  } | Out-Null

  Core-Log "Auth + Isolation + Authorization configurado"
}