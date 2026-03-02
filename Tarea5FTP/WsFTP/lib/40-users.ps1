function New-FTPUserLayout($u, $group){
  # RUTA REAL del usuario para IIS Isolation:
  # C:\FTP\ftproot\LocalUser\<user>\
  $uRoot = Join-Path $Global:T5_LOCALUSER $u

  Ensure-Dir $uRoot

  # Dentro del root del usuario deben aparecer 3 carpetas:
  # general, <grupo>, <usuario>
  $personal = Join-Path $uRoot $u
  Ensure-Dir $personal

  # Junctions para "general" y "grupo"
  Ensure-Junction (Join-Path $uRoot "general") $Global:T5_GENERAL
  Ensure-Junction (Join-Path $uRoot $group) (Join-Path $Global:T5_GROUPS $group)

  # ACL personal (solo el usuario y admin)
  Reset-AclInheritance $personal $false
  Grant-Acl $personal $u "Modify"
  Grant-Acl $personal "Administrators" "FullControl"
  Grant-Acl $personal "SYSTEM" "FullControl"

  Core-Log "Layout usuario OK: $u ($group)"
}

function Ensure-FTPUser($u, $pwd, $group){
  if($group -ne $Global:GROUP_A -and $group -ne $Global:GROUP_B){
    throw "Grupo inválido: $group"
  }

  Ensure-LocalUser $u $pwd

  # Grupo común (RW general)
  Add-ToGroup $Global:COMMON_GROUP $u

  # Grupo específico y remover del otro
  Add-ToGroup $group $u
  if($group -eq $Global:GROUP_A){ Remove-FromGroup $Global:GROUP_B $u } else { Remove-FromGroup $Global:GROUP_A $u }

  # Estructura de carpetas/junctions
  New-FTPUserLayout $u $group
}

function New-FTPUsersWizard {
  Core-Banner "5) Alta masiva de usuarios (wizard)"

  $n = Read-Host "¿Cuántos usuarios crear?"
  if(-not ($n -match '^\d+$') -or [int]$n -lt 1 -or [int]$n -gt 500){
    throw "n inválido (1..500)"
  }

  for($i=1; $i -le [int]$n; $i++){
    Write-Host "---- Usuario $i/$n ----"
    $u = Read-Host "Nombre de usuario"
    $pwd = Read-Host "Contraseña"

    Write-Host "Grupo: 1) $($Global:GROUP_A)  2) $($Global:GROUP_B)"
    $opt = Read-Host "Elige (1/2)"
    $g = if($opt -eq "1"){ $Global:GROUP_A } elseif($opt -eq "2"){ $Global:GROUP_B } else { throw "Opción inválida" }

    Ensure-FTPUser $u $pwd $g
  }

  Core-Log "Alta masiva finalizada"
}