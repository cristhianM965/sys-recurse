Import-Module WebAdministration -ErrorAction SilentlyContinue

$Global:SiteName    = "FTP"
$Global:FtpRoot     = "C:\FTP"
$Global:GeneralPath = Join-Path $Global:FtpRoot "general"
$Global:RepPath     = Join-Path $Global:FtpRoot "reprobados"
$Global:RecPath     = Join-Path $Global:FtpRoot "recursadores"
$Global:UsersPath   = Join-Path $Global:FtpRoot "usuarios"

$Global:Grupo1      = "reprobados"
$Global:Grupo2      = "recursadores"
$Global:PuertoFTP   = 21