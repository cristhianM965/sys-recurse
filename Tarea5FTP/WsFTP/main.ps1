$base = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$base\lib\config.ps1"
. "$base\lib\validadores.ps1"
. "$base\lib\permisos.ps1"
. "$base\lib\ftp.ps1"
. "$base\lib\usuarios.ps1"
. "$base\lib\menu.ps1"

Mostrar-MenuPrincipal