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
  if (-not (Get-LocalUser -Name $username -ErrorAction SilentlyContinue)) {
    $sec = ConvertTo-SecureString $passwordPlain -AsPlainText -Force
    New-LocalUser -Name $username -Password $sec -PasswordNeverExpires:$true -UserMayNotChangePassword:$false | Out-Null
    Core-Log "Usuario creado: $username"
  } else {
    # Actualizar password si ya existe
    $sec = ConvertTo-SecureString $passwordPlain -AsPlainText -Force
    Set-LocalUser -Name $username -Password $sec | Out-Null
    Core-Log "Password actualizado: $username"
  }
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

function Grant-Acl($path, $identity, $rights, $inherit="ContainerInherit,ObjectInherit", $prop="None"){
  $acl = Get-Acl $path
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, $rights, $inherit, $prop, "Allow")
  $acl.SetAccessRule($rule)
  Set-Acl $path $acl
}

function Revoke-AllAcl($path){
  $acl = Get-Acl $path
  foreach($r in @($acl.Access)){ $acl.RemoveAccessRule($r) | Out-Null }
  Set-Acl $path $acl
}