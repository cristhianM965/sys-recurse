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
            Show-Services
            $svc = Read-Host "Seleccione servicio"

            switch ($svc) {
                "1" {
                    $port = Read-Host "Puerto para IIS"

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

                "2" {
                   "2" {
                        $httpPort = Read-Host "Puerto para Tomcat (HTTP)"

                        if (-not (Test-PortAvailable $httpPort)) {
                            Write-Host "Puerto HTTP ocupado"
                            continue
                        }

                        Install-TomcatWeb -Port $httpPort

                        $ssl = Read-Host "¿SSL? (S/N)"

                        if ($ssl -eq "S") {
                            $httpsPort = Read-Host "Puerto para Tomcat (HTTPS)"

                            if (-not (Test-PortAvailable $httpsPort)) {
                                Write-Host "Puerto HTTPS ocupado"
                                continue
                            }

                            Configure-Tomcat-HTTPS -HttpPort $httpPort -HttpsPort $httpsPort
                        }
                    }

                "3" {
                    Write-Host "Nginx (pendiente)"
                }

                "4" {
                    Write-Host "FTP (pendiente)"
                }

                default {
                    Write-Host "Opción inválida"
                }
            }
        }

        "2" {
            break
        }

        default {
            Write-Host "Opción inválida"
        }
    }
}