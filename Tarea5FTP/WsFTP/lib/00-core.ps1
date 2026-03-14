#requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# ===== Config =====
$Global:T5_ROOT      = "C:\FTP"
$Global:T5_SITE_ROOT = Join-Path $Global:T5_ROOT "ftproot"     # raíz del sitio IIS FTP
$Global:T5_GENERAL   = Join-Path $Global:T5_SITE_ROOT "general"
$Global:T5_LOCALUSER = Join-Path $Global:T5_SITE_ROOT "LocalUser" # requerido por IIS FTP User Isolation (IsolateUsers)

$Global:T5_DATA      = Join-Path $Global:T5_ROOT "data"
$Global:T5_GROUPS    = Join-Path $Global:T5_DATA "groups"
$Global:T5_USERSDATA = Join-Path $Global:T5_DATA "users"

$Global:GROUP_A = "reprobados"
$Global:GROUP_B = "recursadores"
$Global:COMMON_GROUP = "ftpusers"

$Global:FTP_SITE_NAME = "FTP-Tarea5"
$Global:FTP_PORT = 21

$Global:T5_LOG = "C:\FTP\tarea5_ftp_windows.log"

function Core-Log($msg){
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg

  # Asegurar que exista la carpeta del log antes de escribir
  $logDir = Split-Path -Parent $Global:T5_LOG
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }

  $line | Tee-Object -FilePath $Global:T5_LOG -Append | Out-Null
}

function Core-Banner($msg){
  Write-Host ""
  Write-Host "========================================"
  Write-Host $msg
  Write-Host "========================================"
  Core-Log $msg
}

function Ensure-Dir($path){
  if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

function Ensure-LocalGroup($name){
  if (-not (Get-LocalGroup -Name $name -ErrorAction SilentlyContinue)) {
    New-LocalGroup -Name $name | Out-Null
    Core-Log "Grupo creado: $name"
  }
}

function Ensure-LocalUser($username, $passwordPlain){
  $passwordPlain = $passwordPlain.Trim()

  if ([string]::IsNullOrWhiteSpace($passwordPlain)) {
    throw "La contraseña no puede estar vacía para el usuario $username"
  }

  if ($passwordPlain.Length -lt 6) {
    throw "La contraseña debe tener al menos 6 caracteres para el usuario $username"
  }

  $sec = ConvertTo-SecureString $passwordPlain -AsPlainText -Force

  if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
    New-LocalUser `
      -Name $username `
      -Password $sec `
      -PasswordNeverExpires:$true `
      -AccountNeverExpires:$true `
      -UserMayNotChangePassword:$false | Out-Null

    Core-Log "Usuario creado: $username"
  } else {
    Set-LocalUser -Name $username -Password $sec | Out-Null
    Core-Log "Password actualizado: $username"
  }

  # Asegurar que esté activo
  & net user $username /active:yes | Out-Null
}

function Add-ToGroup($group, $user){
  try { Add-LocalGroupMember -Group $group -Member $user -ErrorAction Stop | Out-Null } catch {}
}

function Remove-FromGroup($group, $user){
  try { Remove-LocalGroupMember -Group $group -Member $user -Confirm:$false -ErrorAction Stop | Out-Null } catch {}
}

function Ensure-Junction($linkPath, $targetPath){
  if (Test-Path $linkPath) { return }
  Ensure-Dir (Split-Path -Parent $linkPath)
  cmd /c "mklink /J `"$linkPath`" `"$targetPath`"" | Out-Null
}

function Reset-AclInheritance($path, [bool]$disableInheritance){
  $acl = Get-Acl $path
  if ($disableInheritance) { $acl.SetAccessRuleProtection($true, $false) } # no hereda, no copia
  else { $acl.SetAccessRuleProtection($false, $true) } # hereda
  Set-Acl -Path $path -AclObject $acl
}

function Resolve-Identity($identity){
  # Si ya es SID
  if ($identity -match '^S-\d-\d+(-\d+)+$') {
    return New-Object System.Security.Principal.SecurityIdentifier($identity)
  }

  # Mapeos inmunes al idioma (well-known)
  switch -Regex ($identity) {
    '^Administrators$' { return New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544') } # BUILTIN\Administrators
    '^Administradores$' { return New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544') }
    '^SYSTEM$' { return New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18') }             # Local System
    '^IIS_IUSRS$' { return New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-568') }      # IIS_IUSRS
    '^Everyone$' { return New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0') }            # Everyone
  }

  # Intentar traducir nombre normal -> SID
  try {
    $nt = New-Object System.Security.Principal.NTAccount($identity)
    return $nt.Translate([System.Security.Principal.SecurityIdentifier])
  } catch {
    throw "No se pudo resolver la identidad: $identity"
  }
}

function Grant-Acl($path, $identity, $rights, $inherit="ContainerInherit,ObjectInherit", $prop="None"){
  $acl = Get-Acl $path
  $sid = Resolve-Identity $identity
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, $rights, $inherit, $prop, "Allow")
  $acl.SetAccessRule($rule)
  Set-Acl $path $acl
}

function Revoke-AllAcl($path){
  $acl = Get-Acl $path
  foreach($r in @($acl.Access)){ $acl.RemoveAccessRule($r) | Out-Null }
  Set-Acl $path $acl
}