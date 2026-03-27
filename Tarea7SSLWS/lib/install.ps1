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
        throw "No se encontró la carpeta base de Apache después de la instalación."
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

    $apacheService = Get-Service -Name "Apache" -ErrorAction SilentlyContinue
    if (-not $apacheService) {
        $apacheService = Get-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
    }

    if ($apacheService) {
        Write-Host "Reiniciando servicio Apache..." -ForegroundColor Yellow
        Restart-Service -Name $apacheService.Name -Force
    }
    else {
        Write-Host "Instalando servicio Apache..." -ForegroundColor Yellow
        & $httpdExe -k install
        Start-Sleep -Seconds 2

        $apacheService = Get-Service -Name "Apache" -ErrorAction SilentlyContinue
        if (-not $apacheService) {
            $apacheService = Get-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
        }

        if ($apacheService) {
            Start-Service -Name $apacheService.Name
        }
        else {
            throw "Apache fue instalado, pero no se encontró el servicio para iniciarlo."
        }
    }
    $confPath = Join-Path $apacheBase "conf\httpd.conf"
    $conf = Get-Content $confPath -Raw

    if ($conf -notmatch 'Include conf/extra/httpd-ssl.conf') {
        $conf += "`r`nLoadModule ssl_module modules/mod_ssl.so"
        $conf += "`r`nLoadModule socache_shmcb_module modules/mod_socache_shmcb.so"
        $conf += "`r`nInclude conf/extra/httpd-ssl.conf`r`n"
        Set-Content -Path $confPath -Value $conf -Encoding ASCII
    }

    Write-Host "Apache instalado y ejecutándose en puerto $Port" -ForegroundColor Green
}

function Ensure-OpenSSL {
    Write-Host "Verificando OpenSSL..." -ForegroundColor Cyan

    if (Test-Path $OPENSSL_EXE) {
        Write-Host "OpenSSL ya está instalado." -ForegroundColor Green
        return
    }

    Ensure-Chocolatey

    Write-Host "OpenSSL no encontrado. Instalando OpenSSL.Light..." -ForegroundColor Yellow

    choco install openssl.light -y --no-progress

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo instalar OpenSSL con Chocolatey."
    }

    $possibleOpenSSL = @(
        "C:\Program Files\OpenSSL-Win64\bin\openssl.exe",
        "C:\Program Files\OpenSSL-Win32\bin\openssl.exe",
        "C:\tools\OpenSSL-Win64\bin\openssl.exe",
        "C:\ProgramData\chocolatey\bin\openssl.exe"
    )

    $found = $possibleOpenSSL | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $found) {
        $found = Get-ChildItem -Path "C:\" -Filter "openssl.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $found) {
        throw "OpenSSL fue instalado, pero no se encontró openssl.exe"
    }

    $script:OPENSSL_EXE = $found
    Write-Host "OpenSSL detectado en: $script:OPENSSL_EXE" -ForegroundColor Green
}