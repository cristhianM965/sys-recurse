function Install-Apache {

    $port = Read-Number "Puerto Apache"

    if (-not (Test-PortFree $port)) {
        Write-Host "Puerto ocupado"
        return
    }

    Write-Host "Instalando Apache con winget..."

    winget install ApacheFriends.Xampp --silent

    $conf = "C:\xampp\apache\conf\httpd.conf"

    if (Test-Path $conf) {

        (Get-Content $conf) -replace "Listen 80", "Listen $port" |
        Set-Content $conf

        Open-FirewallPort $port

        Start-Service apache2.4

        Validate-HTTP $port
    }
}