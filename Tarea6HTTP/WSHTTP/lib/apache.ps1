function Install-Apache {
    Ensure-Chocolatey

    $versions = Get-ChocoVersions "apache-httpd"
    $version = Select-VersionFromList "Apache" $versions
    $port = Read-Port

    Write-Host "Instalando Apache $version ..."
    choco install apache-httpd --version=$version -y --no-progress

    $basePath = "C:\tools\Apache24"
    $conf = Join-Path $basePath "conf\httpd.conf"

    if (-not (Test-Path $conf)) {
        throw "No se encontró httpd.conf en $conf"
    }

    (Get-Content $conf) `
        -replace '^Listen\s+\d+', "Listen $port" `
        -replace 'ServerTokens\s+\w+', 'ServerTokens Prod' `
        -replace 'ServerSignature\s+\w+', 'ServerSignature Off' |
        Set-Content $conf

    if (-not (Select-String -Path $conf -Pattern '^TraceEnable Off' -Quiet)) {
        Add-Content $conf "`nTraceEnable Off"
    }

    Open-FirewallPort $port

    $httpdExe = Join-Path $basePath "bin\httpd.exe"
    if (Test-Path $httpdExe) {
        & $httpdExe -k restart 2>$null
        if ($LASTEXITCODE -ne 0) {
            & $httpdExe -k install 2>$null
            & $httpdExe -k start
        }
    }

    Validate-HTTP $port
}

function Uninstall-Apache {
    Ensure-Chocolatey

    Stop-ProcessIfRunning "httpd"
    choco uninstall apache-httpd -y --no-progress

    Write-Host "Apache desinstalado."
}