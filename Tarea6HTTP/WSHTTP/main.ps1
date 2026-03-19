$ErrorActionPreference = "Stop"

$BASE_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$BASE_DIR\lib\common.ps1"
. "$BASE_DIR\lib\iis.ps1"
. "$BASE_DIR\lib\apache.ps1"
. "$BASE_DIR\lib\nginx.ps1"
. "$BASE_DIR\lib\menu.ps1"

Show-MainMenu