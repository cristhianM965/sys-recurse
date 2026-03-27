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

    $possibleBases = @(
        "C:\tools\Apache24",
        "C:\Apache24",
        "C:\Program Files\Apache24"
    )

    $apacheBase = $possibleBases | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $apacheBase) {
        throw "No se encontró la carpeta base de Apache después de la instalación."
    }

    $confPath = Join-Path $apacheBase "conf\httpd.conf"
    if (-not (Test-Path $confPath)) {
        throw "No se encontró httpd.conf en $confPath"
    }

    Write-Host "Configurando Apache en puerto $Port..." -ForegroundColor Yellow

    $conf = Get-Content $confPath -Raw
    $conf = $conf -replace 'Listen\s+\d+', "Listen $Port"
    $conf = $conf -replace '#?ServerName\s+.*', "ServerName localhost:$Port"
    Set-Content -Path $confPath -Value $conf -Encoding ASCII

    $htdocs = Join-Path $apacheBase "htdocs\index.html"
    if (Test-Path $htdocs) {
        Set-Content -Path $htdocs -Value "<h1>Apache Windows - reprobados.com</h1>" -Encoding ASCII
    }

    $httpdExe = Join-Path $apacheBase "bin\httpd.exe"
    if (-not (Test-Path $httpdExe)) {
        throw "No se encontró httpd.exe en $httpdExe"
    }

    Write-Host "Validando configuración de Apache..." -ForegroundColor Yellow
    & $httpdExe -t
    if ($LASTEXITCODE -ne 0) {
        throw "La configuración de Apache no es válida."
    }

    Write-Host "Reiniciando/levantando Apache..." -ForegroundColor Yellow

    $apacheService = Get-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
    if ($apacheService) {
        Restart-Service -Name "Apache2.4" -Force
    }
    else {
        & $httpdExe -k install
        Start-Service -Name "Apache2.4"
    }

    Write-Host "Apache instalado y ejecutándose en puerto $Port" -ForegroundColor Green
}