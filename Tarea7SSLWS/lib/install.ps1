function Install-IIS {
    Write-Host "Instalando IIS..."

    Install-WindowsFeature -Name Web-Server -IncludeManagementTools

    if (!(Get-Service W3SVC -ErrorAction SilentlyContinue)) {
        throw "IIS no se instaló correctamente"
    }

    Start-Service W3SVC

    Write-Host "IIS instalado y en ejecución"
}


function Ensure-Chocolatey {
    Write-Host "Verificando Chocolatey..." -ForegroundColor Cyan

    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue

    if ($chocoCmd) {
        Write-Host "Chocolatey ya está instalado." -ForegroundColor Green
        return
    }

    Write-Host "Chocolatey no está instalado. Instalando..." -ForegroundColor Yellow

    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    $env:Path += ";C:\ProgramData\chocolatey\bin"

    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoCmd) {
        throw "No se pudo instalar Chocolatey correctamente."
    }

    Write-Host "Chocolatey instalado correctamente." -ForegroundColor Green
}

function Install-ApacheWeb {
    param(
        [int]$Port
    )

    Write-Host "Instalando Apache con Chocolatey..." -ForegroundColor Cyan

    Ensure-Chocolatey

    choco install apache-httpd -y --no-progress

    if ($LASTEXITCODE -ne 0) {
        throw "Error instalando Apache con Chocolatey."
    }

    $apacheService = Get-Service -Name "Apache" -ErrorAction SilentlyContinue

    if (-not $apacheService) {
        throw "El servicio Apache no fue encontrado después de la instalación."
    }

    $serviceInfo = Get-CimInstance Win32_Service -Filter "Name='Apache'"
    $servicePath = $serviceInfo.PathName

    if (-not $servicePath) {
        throw "No se pudo obtener la ruta del servicio Apache."
    }

    $httpdExe = [regex]::Match($servicePath, '"([^"]*httpd\.exe)"').Groups[1].Value

    if (-not $httpdExe) {
        $httpdExe = ($servicePath -split '\s+')[0]
    }

    if (-not (Test-Path $httpdExe)) {
        throw "No se encontró httpd.exe en la ruta detectada: $httpdExe"
    }

    $apacheBase = Split-Path (Split-Path $httpdExe -Parent) -Parent

    if (-not (Test-Path $apacheBase)) {
        throw "No se encontró la carpeta base de Apache: $apacheBase"
    }

    Write-Host "Apache detectado en: $apacheBase" -ForegroundColor Green

    $confPath = Join-Path $apacheBase "conf\httpd.conf"
    if (-not (Test-Path $confPath)) {
        throw "No se encontró httpd.conf en $confPath"
    }

    Write-Host "Configurando Apache en puerto $Port..." -ForegroundColor Yellow

    $conf = Get-Content $confPath -Raw
    $conf = $conf -replace 'Listen\s+\d+', "Listen $Port"
    $conf = $conf -replace '#?ServerName\s+.*', "ServerName localhost:$Port"

    if ($conf -notmatch 'LoadModule ssl_module modules/mod_ssl.so') {
        $conf += "`r`nLoadModule ssl_module modules/mod_ssl.so"
    }

    if ($conf -notmatch 'LoadModule socache_shmcb_module modules/mod_socache_shmcb.so') {
        $conf += "`r`nLoadModule socache_shmcb_module modules/mod_socache_shmcb.so"
    }

    if ($conf -notmatch 'Include conf/extra/httpd-ssl.conf') {
        $conf += "`r`nInclude conf/extra/httpd-ssl.conf"
    }

    Set-Content -Path $confPath -Value $conf -Encoding ASCII

    $htdocs = Join-Path $apacheBase "htdocs\index.html"
    if (Test-Path $htdocs) {
        Set-Content -Path $htdocs -Value "<h1>Apache Windows - reprobados.com</h1>" -Encoding ASCII
    }

    Write-Host "Validando configuración de Apache..." -ForegroundColor Yellow
    & $httpdExe -t
    if ($LASTEXITCODE -ne 0) {
        throw "La configuración de Apache no es válida."
    }

    Restart-Service -Name "Apache" -Force

    Write-Host "Apache instalado y ejecutándose en puerto $Port" -ForegroundColor Green
}