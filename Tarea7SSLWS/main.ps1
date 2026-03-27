. .\config.ps1
. .\lib\core.ps1
. .\lib\menu.ps1
. .\lib\ports.ps1
. .\lib\install.ps1
. .\lib\ssl.ps1

while ($true) {

    Show-Menu
    $opt = Read-Host "Seleccione opción"

    switch ($opt) {

        "1" {
            Write-Host "1) IIS"
            $svc = Read-Host "Seleccione servicio"

            if ($svc -eq "1") {

                $port = Read-Host "Puerto"

                if (-not (Test-PortAvailable $port)) {
                    Write-Host "Puerto ocupado"
                    continue
                }

                Install-IIS

                $ssl = Read-Host "¿SSL? (S/N)"

                if ($ssl -eq "S") {
                    $cert = New-SSL-Cert -Domain $DOMAIN
                    Configure-IIS-HTTPS -Port $port -Cert $cert
                }
            }
        }

        "2" {
            break
        }
    }
}