#requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$DIR\lib\00-core.ps1"
. "$DIR\lib\10-install-iisftp.ps1"
. "$DIR\lib\20-structure-acl.ps1"
. "$DIR\lib\30-iis-site.ps1"
. "$DIR\lib\40-users.ps1"
. "$DIR\lib\50-change-group.ps1"

Core-Banner "Tarea 5 - FTP Windows (IIS) - Modular"

Install-IISFTP
Init-FTPStructure
Set-BaseNTFSPerms
New-OrUpdate-IISFTPSite

# Alta masiva (wizard)
New-FTPUsersWizard

Core-Banner "Listo. Prueba: anonymous (solo lectura en /general) y alumno (RW en /general, /<grupo>, /<usuario>)"
Write-Host "Log: $($Global:T5_LOG)"