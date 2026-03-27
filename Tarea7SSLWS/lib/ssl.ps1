
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

function Ensure-Tomcat-Cert {
    New-Item -ItemType Directory -Force -Path $TOMCAT_CERT_DIR | Out-Null

    if (Test-Path $TOMCAT_CERT_P12) {
        Write-Host "Certificado PKCS12 de Tomcat existente detectado, reutilizando..." -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $OPENSSL_EXE)) {
        Ensure-OpenSSL
    }

    if (-not (Test-Path $OPENSSL_EXE)) {
        throw "No se encontró openssl.exe"
    }

    Write-Host "Generando certificado PKCS12 para Tomcat..." -ForegroundColor Cyan

    $tempKey = Join-Path $TOMCAT_CERT_DIR "tomcat-temp.key"
    $tempCrt = Join-Path $TOMCAT_CERT_DIR "tomcat-temp.crt"

    & $OPENSSL_EXE req -x509 -nodes -days 365 -newkey rsa:2048 `
        -keyout $tempKey `
        -out $tempCrt `
        -subj "/C=MX/ST=Sinaloa/L=LosMochis/O=UAS/OU=SysAdmin/CN=$DOMAIN"

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo generar el certificado temporal de Tomcat."
    }

    & $OPENSSL_EXE pkcs12 -export `
        -out $TOMCAT_CERT_P12 `
        -inkey $tempKey `
        -in $tempCrt `
        -passout pass:$TOMCAT_P12_PASS

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo generar el archivo P12 de Tomcat."
    }

    Remove-Item $tempKey -Force -ErrorAction SilentlyContinue
    Remove-Item $tempCrt -Force -ErrorAction SilentlyContinue
}

function Configure-Tomcat-HTTPS {
    param(
        [int]$HttpPort,
        [int]$HttpsPort
    )

    Ensure-Tomcat-Cert

    $tomcatBase = Get-TomcatBase
    Write-Host "Configurando SSL para Tomcat en: $tomcatBase" -ForegroundColor Cyan

    $serverXml = Join-Path $tomcatBase "conf\server.xml"
    if (-not (Test-Path $serverXml)) {
        throw "No se encontró server.xml"
    }

    $xml = Get-Content $serverXml -Raw

    $xml = $xml -replace 'port="8080"', "port=""$HttpPort"""
    $xml = $xml -replace 'redirectPort="8443"', "redirectPort=""$HttpsPort"""

    $xml = $xml -replace '(?s)<Connector port="8443".*?/>', ''

    $httpsConnector = @"
<Connector port="$HttpsPort"
           protocol="org.apache.coyote.http11.Http11NioProtocol"
           maxThreads="150"
           SSLEnabled="true"
           scheme="https"
           secure="true">
    <SSLHostConfig>
        <Certificate certificateKeystoreFile="$($TOMCAT_CERT_P12 -replace '\\','/')"
                     certificateKeystorePassword="$TOMCAT_P12_PASS"
                     certificateKeystoreType="PKCS12" />
    </SSLHostConfig>
</Connector>
"@

    if ($xml -notmatch [regex]::Escape("certificateKeystoreFile")) {
        $xml = $xml -replace '</Service>', "$httpsConnector`r`n</Service>"
    }

    Set-Content -Path $serverXml -Value $xml -Encoding UTF8

    $service = Get-Service -Name "Tomcat*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $service) {
        throw "No se encontró el servicio de Tomcat para reiniciarlo."
    }

    Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Service -Name $service.Name
    Start-Sleep -Seconds 3

    Write-Host "Tomcat HTTPS activo en puerto $HttpsPort" -ForegroundColor Green
}

