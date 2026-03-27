
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