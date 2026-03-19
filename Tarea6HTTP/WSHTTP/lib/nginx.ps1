function Install-Nginx {
    Ensure-Chocolatey

    $versions = Get-ChocoVersions "nginx"
    $version = Select-VersionFromList "Nginx" $versions
    $port = Read-Port

    Write-Host "Instalando Nginx $version ..."
    choco install nginx --version=$version -y --no-progress

    $candidates = @(
        "C:\tools\nginx-*",
        "C:\tools\nginx",
        "C:\ProgramData\chocolatey\lib\nginx\tools\nginx-*",
        "C:\Program Files\nginx"
    )

    $nginxRoot = $null

    foreach ($candidate in $candidates) {
        $found = Get-ChildItem -Path $candidate -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $nginxRoot = $found.FullName
            break
        }

        if ((Test-Path $candidate) -and (Get-Item $candidate).PSIsContainer) {
            $nginxRoot = (Get-Item $candidate).FullName
            break
        }
    }

    if (-not $nginxRoot) {
        throw "No se encontró la carpeta de Nginx."
    }

    $conf = Join-Path $nginxRoot "conf\nginx.conf"
    $exe  = Join-Path $nginxRoot "nginx.exe"

    if (-not (Test-Path $conf)) {
        throw "No se encontró nginx.conf en $conf"
    }

    (Get-Content $conf) `
        -replace 'listen\s+80;', "listen $port;" `
        -replace '#server_tokens off;', 'server_tokens off;' |
        Set-Content $conf

    Open-FirewallPort $port

    Stop-ProcessIfRunning "nginx"
    Start-Process $exe -WorkingDirectory $nginxRoot

    Validate-HTTP $port
}

function Uninstall-Nginx {
    Ensure-Chocolatey

    Stop-ProcessIfRunning "nginx"
    choco uninstall nginx -y --no-progress

    Write-Host "Nginx desinstalado."
}