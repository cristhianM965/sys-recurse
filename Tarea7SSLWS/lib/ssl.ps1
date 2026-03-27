
function New-SSL-Cert {
    param(
        [string]$Domain = "reprobados.com"
    )

    Write-Host "Generando certificado SSL..."

    $cert = New-SelfSignedCertificate `
        -DnsName $Domain `
        -CertStoreLocation "Cert:\LocalMachine\My"

    return $cert
}

function Configure-IIS-HTTPS {
    param($Port, $Cert)

    Import-Module WebAdministration

    New-WebBinding -Name "Default Web Site" -Protocol https -Port $Port -ErrorAction SilentlyContinue

    New-Item "IIS:\SslBindings\0.0.0.0!$Port" -Value $Cert -ErrorAction SilentlyContinue

    Write-Host "HTTPS activo en $Port"
}

function Ensure-Apache-Cert {
    New-Item -ItemType Directory -Force -Path $APACHE_CERT_DIR | Out-Null

    if ((Test-Path $APACHE_CERT_CRT) -and (Test-Path $APACHE_CERT_KEY)) {
        Write-Host "Certificado Apache existente detectado, reutilizando..." -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $OPENSSL_EXE)) {
    Ensure-OpenSSL
    }

    if (-not (Test-Path $OPENSSL_EXE)) {
    throw "No se encontró openssl en: $OPENSSL_EXE"
    }

    Write-Host "Generando certificado autofirmado para Apache..." -ForegroundColor Cyan

    & $OPENSSL_EXE req -x509 -nodes -days 365 -newkey rsa:2048 `
        -keyout $APACHE_CERT_KEY `
        -out $APACHE_CERT_CRT `
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=UAS/OU=SysAdmin/CN=$DOMAIN"

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo generar el certificado SSL de Apache."
    }
}

function Configure-Apache-HTTPS {
    param(
        [int]$HttpsPort
    )

    Ensure-Apache-Cert

    $possibleBases = @(
        "C:\tools\Apache24",
        "C:\Apache24",
        "C:\Program Files\Apache24",
        "$env:APPDATA\Apache24",
        "$env:USERPROFILE\AppData\Roaming\Apache24"
    )

    $apacheBase = $possibleBases | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $apacheBase) {
        $foundHttpd = Get-ChildItem -Path "C:\" -Filter "httpd.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($foundHttpd) {
            $apacheBase = Split-Path (Split-Path $foundHttpd.FullName -Parent) -Parent
        }
    }

    if (-not $apacheBase) {
        throw "No se encontró la carpeta base de Apache."
    }

    $sslConf = Join-Path $apacheBase "conf\extra\httpd-ssl.conf"
    if (-not (Test-Path $sslConf)) {
        throw "No se encontró httpd-ssl.conf en $sslConf"
    }

    Write-Host "Configurando HTTPS para Apache en puerto $HttpsPort..." -ForegroundColor Cyan

    $ssl = Get-Content $sslConf -Raw

    $ssl = $ssl -replace 'Listen\s+\d+', "Listen $HttpsPort"
    $ssl = $ssl -replace '<VirtualHost _default_:\d+>', "<VirtualHost _default_:$HttpsPort>"
    $ssl = $ssl -replace 'ServerName\s+.*', "ServerName localhost:$HttpsPort"
    $ssl = $ssl -replace 'SSLCertificateFile\s+".*"', "SSLCertificateFile `"$APACHE_CERT_CRT`""
    $ssl = $ssl -replace 'SSLCertificateKeyFile\s+".*"', "SSLCertificateKeyFile `"$APACHE_CERT_KEY`""

    Set-Content -Path $sslConf -Value $ssl -Encoding ASCII

    $httpdExe = Join-Path $apacheBase "bin\httpd.exe"
    & $httpdExe -t
    if ($LASTEXITCODE -ne 0) {
        throw "La configuración SSL de Apache no es válida."
    }

    $apacheService = Get-Service -Name "Apache" -ErrorAction SilentlyContinue
    if (-not $apacheService) {
        $apacheService = Get-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
    }

    if ($apacheService) {
        Write-Host "Reiniciando Apache correctamente..." -ForegroundColor Yellow

        Stop-Service -Name "Apache" -Force
        Start-Sleep -Seconds 3

        Start-Service -Name "Apache"
        Start-Sleep -Seconds 2
    }
    else {
        throw "No se encontró el servicio de Apache para reiniciarlo."
    }

    Write-Host "Apache HTTPS activo en puerto $HttpsPort" -ForegroundColor Green
}