function Install-Nginx {

    $port = Read-Number "Puerto Nginx"

    if (-not (Test-PortFree $port)) {
        Write-Host "Puerto ocupado"
        return
    }

    Write-Host "Instalando Nginx..."

    winget install nginx.nginx --silent

    $conf = "C:\Program Files\nginx\conf\nginx.conf"

    if (Test-Path $conf) {

        (Get-Content $conf) -replace "listen 80;", "listen $port;" |
        Set-Content $conf

        Open-FirewallPort $port

        Start-Process "C:\Program Files\nginx\nginx.exe"

        Validate-HTTP $port
    }
}