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

function Get-TomcatBase {
    $candidates = @()

    # 1. Intentar obtener ruta desde servicios registrados
    $services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*tomcat*" -or $_.DisplayName -like "*tomcat*" }

    foreach ($svc in $services) {
        $path = $svc.PathName

        $serviceExe = [regex]::Match($path, '"([^"]*tomcat.*?\.exe)"').Groups[1].Value
        if (-not $serviceExe) {
            $serviceExe = [regex]::Match($path, '([A-Za-z]:\\[^"]*tomcat.*?\.exe)').Groups[1].Value
        }

        if ($serviceExe -and (Test-Path $serviceExe)) {
            $base = Split-Path (Split-Path $serviceExe -Parent) -Parent
            $candidates += $base
        }
    }

    # 2. Rutas comunes reales
    $candidates += @(
        "C:\Program Files\Apache Software Foundation\Tomcat 10.1",
        "C:\Program Files\Apache Software Foundation\Tomcat 10.0",
        "C:\Tomcat",
        "$env:ProgramFiles\Apache Software Foundation\Tomcat 10.1",
        "$env:ProgramFiles\Apache Software Foundation\Tomcat 10.0"
    )

    # 3. Buscar carpetas que realmente tengan server.xml
    $serverXmlFound = Get-ChildItem -Path "C:\" -Filter "server.xml" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\conf\\server\.xml$' } |
        Select-Object -First 1

    if ($serverXmlFound) {
        $realBase = Split-Path (Split-Path $serverXmlFound.FullName -Parent) -Parent
        $candidates += $realBase
    }

    # 4. Validar candidatos
    $validBase = $candidates |
        Where-Object { $_ -and (Test-Path $_) } |
        Select-Object -Unique |
        Where-Object {
            (Test-Path (Join-Path $_ "conf\server.xml")) -and
            (Test-Path (Join-Path $_ "bin")) -and
            (Test-Path (Join-Path $_ "webapps"))
        } |
        Select-Object -First 1

    if ($validBase) {
        return $validBase
    }

    throw "No se encontró una instalación válida de Tomcat con conf\server.xml."
}
function Install-TomcatWeb {
    param(
        [int]$Port
    )

    Write-Host "Instalando Tomcat..." -ForegroundColor Cyan

    Ensure-Chocolatey
    Ensure-Java

    choco install tomcat -y --no-progress

    choco install tomcat -y --no-progress

    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo instalar Tomcat con Chocolatey."
    }

    Start-Sleep -Seconds 8

    $tomcatBase = Get-TomcatBase

    $tomcatBase = Get-TomcatBase
    Write-Host "Tomcat detectado en: $tomcatBase" -ForegroundColor Green

    $serverXml = Join-Path $tomcatBase "conf\server.xml"
    if (-not (Test-Path $serverXml)) {
        throw "No se encontró server.xml en $serverXml"
    }

    $xml = Get-Content $serverXml -Raw

    $xml = $xml -replace 'port="8080"', "port=""$Port"""
    $xml = $xml -replace 'redirectPort="8443"', 'redirectPort="8443"'

    Set-Content -Path $serverXml -Value $xml -Encoding UTF8

    $rootIndex = Join-Path $tomcatBase "webapps\ROOT\index.jsp"
    if (Test-Path $rootIndex) {
        Set-Content -Path $rootIndex -Value "<html><body><h1>Tomcat Windows - reprobados.com</h1></body></html>" -Encoding UTF8
    }

    $service = Get-Service -Name "Tomcat*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($service) {
        Restart-Service -Name $service.Name -Force
    }
    else {
        throw "No se encontró el servicio de Tomcat."
    }

    Write-Host "Tomcat instalado y ejecutándose en puerto $Port" -ForegroundColor Green
}