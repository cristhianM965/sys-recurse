# lib/20-structure-acl.ps1
#requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

function Init-FTPStructure {
  Core-Banner "2) Estructura base (general, groups, LocalUser) + grupos"

  # Grupos requeridos
  Ensure-LocalGroup $Global:GROUP_A
  Ensure-LocalGroup $Global:GROUP_B
  Ensure-LocalGroup $Global:COMMON_GROUP

  # Estructura física del sitio IIS FTP
  Ensure-Dir $Global:T5_ROOT
  Ensure-Dir $Global:T5_SITE_ROOT
  Ensure-Dir $Global:T5_GENERAL
  Ensure-Dir $Global:T5_LOCALUSER

  # Datos (carpetas reales para grupos/usuarios)
  Ensure-Dir $Global:T5_DATA
  Ensure-Dir $Global:T5_GROUPS
  Ensure-Dir (Join-Path $Global:T5_GROUPS $Global:GROUP_A)
  Ensure-Dir (Join-Path $Global:T5_GROUPS $Global:GROUP_B)
  Ensure-Dir $Global:T5_USERSDATA

  Core-Log "Estructura creada/validada"
}

function Set-BaseNTFSPerms {
  Core-Banner "3) Permisos NTFS base (anónimo RO en /general, autenticados RW)"

  # =========================
  # /general
  # - Anonymous (IUSR/IIS_IUSRS): Read
  # - Autenticados (ftpusers): Modify
  # =========================
  Ensure-Dir $Global:T5_GENERAL

  # Mantener herencia en general (no es crítico), pero lo dejamos explícito
  Reset-AclInheritance $Global:T5_GENERAL $false

  # Lectura para identidades IIS
  Grant-Acl $Global:T5_GENERAL "IIS_IUSRS" "ReadAndExecute"
  Grant-Acl $Global:T5_GENERAL "IUSR"      "ReadAndExecute"

  # Escritura para autenticados (grupo común)
  Grant-Acl $Global:T5_GENERAL $Global:COMMON_GROUP "Modify"

  # =========================
  # Carpetas de grupo reales (datos)
  # - reprobados: Modify al grupo reprobados
  # - recursadores: Modify al grupo recursadores
  # =========================
  $ga = Join-Path $Global:T5_GROUPS $Global:GROUP_A
  $gb = Join-Path $Global:T5_GROUPS $Global:GROUP_B

  Ensure-Dir $ga
  Ensure-Dir $gb

  Reset-AclInheritance $ga $false
  Reset-AclInheritance $gb $false

  Grant-Acl $ga $Global:GROUP_A "Modify"
  Grant-Acl $gb $Global:GROUP_B "Modify"

  # =========================
  # BLOQUEAR listado de LocalUser al ANÓNIMO
  # Para que anonymous NO vea "LocalUser" y por tanto solo vea /general.
  # OJO: Con User Isolation, los autenticados NO necesitan listar LocalUser.
  # =========================
  Ensure-Dir $Global:T5_LOCALUSER

  # Limpia permisos existentes y corta herencia para evitar "fugas"
  Revoke-AllAcl $Global:T5_LOCALUSER
  Reset-AclInheritance $Global:T5_LOCALUSER $true

  # Solo Administrators y SYSTEM
  Grant-Acl $Global:T5_LOCALUSER "Administrators" "FullControl"
  Grant-Acl $Global:T5_LOCALUSER "SYSTEM" "FullControl"

  Core-Log "ACL base aplicada correctamente (general/grupos/LocalUser)"
}