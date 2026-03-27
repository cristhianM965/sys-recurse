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

function Ensure-Java {
    Write-Host "Verificando Java..." -ForegroundColor Cyan

    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        Write-Host "Java ya está disponible." -ForegroundColor Green
        return
    }

    Ensure-Chocolatey

    Write-Host "Java no encontrado. Instalando Temurin 17..." -ForegroundColor Yellow
    choco install temurin17jre -y --no-progress

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo instalar Java."
    }

    $env:Path += ";C:\Program Files\Eclipse Adoptium\jre-17.0.*\bin"
    Write-Host "Java instalado." -ForegroundColor Green
}

function Install-TomcatWeb {
    param(
        [int]$Port
    )

    Write-Host "Instalando Tomcat..." -ForegroundColor Cyan

    Ensure-Java

    $BASE_DIR = "C:\Tarea7"
    $ZIP = "$BASE_DIR\tomcat.zip"

    if (!(Test-Path $BASE_DIR)) {
        New-Item -ItemType Directory -Path $BASE_DIR | Out-Null
    }

    if (!(Test-Path $TOMCAT_BASE)) {

        Write-Host "Descargando Tomcat..." -ForegroundColor Yellow

        $url = "https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.19/bin/apache-tomcat-10.1.19-windows-x64.zip"

        Invoke-WebRequest -Uri $url -OutFile $ZIP

        if (!(Test-Path $ZIP)) {
            throw "No se pudo descargar Tomcat"
        }

        Write-Host "Extrayendo Tomcat..." -ForegroundColor Yellow

        Expand-Archive $ZIP -DestinationPath $BASE_DIR -Force
    }

    $serverXml = Join-Path $TOMCAT_BASE "conf\server.xml"

    if (!(Test-Path $serverXml)) {
        throw "Tomcat inválido: no existe server.xml"
    }

    # configurar puerto HTTP
    $xml = Get-Content $serverXml -Raw
    $xml = $xml -replace 'port="8080"', "port=""$Port"""
    Set-Content $serverXml $xml -Encoding UTF8

    # página prueba
    Set-Content (Join-Path $TOMCAT_BASE "webapps\ROOT\index.jsp") "<h1>Tomcat HTTP OK</h1>"

    # iniciar Tomcat
    $startup = Join-Path $TOMCAT_BASE "bin\startup.bat"

    if (!(Test-Path $startup)) {
        throw "No se encontró startup.bat"
    }

    Start-Process $startup -NoNewWindow

    Write-Host "Tomcat HTTP en puerto $Port" -ForegroundColor Green
}