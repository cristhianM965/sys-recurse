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

    Write-Host "Instalando Tomcat REAL..." -ForegroundColor Cyan

    Ensure-Java

    $baseDir = "C:\Tarea7"
    $zipPath = "$baseDir\tomcat.zip"
    $extractPath = "$baseDir\Tomcat"

    if (!(Test-Path $baseDir)) {
        New-Item -ItemType Directory -Path $baseDir | Out-Null
    }

    # Descargar Tomcat
    Write-Host "Descargando Tomcat..." -ForegroundColor Yellow

    $url = "https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.28/bin/apache-tomcat-10.1.28-windows-x64.zip"
    Invoke-WebRequest -Uri $url -OutFile $zipPath

    if (!(Test-Path $zipPath)) {
        throw "No se pudo descargar Tomcat."
    }

    # Extraer
    Write-Host "Extrayendo Tomcat..." -ForegroundColor Yellow

    Expand-Archive -Path $zipPath -DestinationPath $baseDir -Force

    $tomcatFolder = Get-ChildItem $baseDir -Directory |
        Where-Object { $_.Name -like "apache-tomcat*" } |
        Select-Object -First 1

    if (-not $tomcatFolder) {
        throw "No se encontró la carpeta extraída de Tomcat."
    }

    $tomcatBase = $tomcatFolder.FullName
    Write-Host "Tomcat instalado en: $tomcatBase" -ForegroundColor Green

    # Validar estructura
    $serverXml = Join-Path $tomcatBase "conf\server.xml"
    if (!(Test-Path $serverXml)) {
        throw "Tomcat no contiene server.xml. Instalación inválida."
    }

    # Configurar puerto
    Write-Host "Configurando puerto $Port..." -ForegroundColor Yellow

    $xml = Get-Content $serverXml -Raw
    $xml = $xml -replace 'port="8080"', "port=""$Port"""
    Set-Content -Path $serverXml -Value $xml -Encoding UTF8

    # Página de prueba
    $rootIndex = Join-Path $tomcatBase "webapps\ROOT\index.jsp"
    Set-Content -Path $rootIndex -Value "<html><body><h1>Tomcat OK - reprobados.com</h1></body></html>" -Encoding UTF8

    # Iniciar Tomcat
    Write-Host "Iniciando Tomcat..." -ForegroundColor Yellow

    $startup = Join-Path $tomcatBase "bin\startup.bat"

    if (!(Test-Path $startup)) {
        throw "No se encontró startup.bat"
    }

    Start-Process $startup

    Write-Host "Tomcat corriendo en puerto $Port" -ForegroundColor Green
}