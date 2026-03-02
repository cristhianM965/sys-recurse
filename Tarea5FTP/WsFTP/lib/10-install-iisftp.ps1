function Install-IISFTP {
  Core-Banner "1) Instalación IIS + FTP (idempotente)"

  $features = @("Web-Server","Web-FTP-Server","Web-FTP-Service","Web-FTP-Ext")
  foreach($f in $features){
    $st = Get-WindowsFeature $f
    if(-not $st.Installed){
      Install-WindowsFeature -Name $f -IncludeManagementTools | Out-Null
      Core-Log "Feature instalada: $f"
    } else {
      Core-Log "Feature ya instalada: $f"
    }
  }

  Import-Module WebAdministration
}