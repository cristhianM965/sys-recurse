function Install-IIS {
    Write-Host "Instalando IIS..."

    Install-WindowsFeature -Name Web-Server -IncludeManagementTools

    if (!(Get-Service W3SVC -ErrorAction SilentlyContinue)) {
        throw "IIS no se instaló correctamente"
    }

    Start-Service W3SVC

    Write-Host "IIS instalado y en ejecución"
}


function Install-ApacheWeb {
    param(
        [int]$Port
    )

    Write-Host "Instalando Apache para Windows..." -ForegroundColor Cyan

    New-Item -ItemType Directory -Force -Path $DOWNLOAD_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path "C:\Tarea7" | Out-Null

    if (-not (Test-Path $APACHE_ZIP)) {
        Write-Host "Descargando Apache..." -ForegroundColor Yellow
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $APACHE_WEB_URL -OutFile $APACHE_ZIP -MaximumRedirection 5 -UseBasicParsing
        }
        catch {
            throw "No se pudo descargar Apache. Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "ZIP de Apache ya existe, reutilizando..." -ForegroundColor Yellow
    }

    if (-not (Test-Path $APACHE_ZIP)) {
        throw "No existe el archivo ZIP de Apache en $APACHE_ZIP"
    }

    if (Test-Path $APACHE_BASE) {
        Write-Host "Apache ya existe en $APACHE_BASE, se reutilizará." -ForegroundColor Yellow
    }
    else {
        Write-Host "Extrayendo Apache..." -ForegroundColor Yellow
        Expand-Archive -Path $APACHE_ZIP -DestinationPath "C:\Tarea7" -Force

        $extracted = Get-ChildItem "C:\Tarea7" -Directory | Where-Object {
            $_.Name -like "Apache24*" -or $_.Name -like "httpd*"
        } | Select-Object -First 1

        if (-not $extracted) {
            throw "No se encontró la carpeta extraída de Apache."
        }

        if ($extracted.FullName -ne $APACHE_BASE) {
            Rename-Item -Path $extracted.FullName -NewName "Apache24" -Force
        }
    }

    $confPath = Join-Path $APACHE_BASE "conf\httpd.conf"
    if (-not (Test-Path $confPath)) {
        throw "No se encontró httpd.conf en $confPath"
    }

    Write-Host "Configurando Apache en puerto $Port..." -ForegroundColor Yellow
    $conf = Get-Content $confPath -Raw
    $conf = $conf -replace 'Listen\s+\d+', "Listen $Port"
    $conf = $conf -replace '#?ServerName\s+.*', "ServerName localhost:$Port"
    Set-Content -Path $confPath -Value $conf -Encoding ASCII

    $htdocs = Join-Path $APACHE_BASE "htdocs\index.html"
    Set-Content -Path $htdocs -Value "<h1>Apache Windows - reprobados.com</h1>" -Encoding ASCII

    $httpdExe = Join-Path $APACHE_BASE "bin\httpd.exe"

    & $httpdExe -t
    if ($LASTEXITCODE -ne 0) {
        throw "La configuración de Apache no es válida."
    }

    & $httpdExe -k uninstall 2>$null | Out-Null
    & $httpdExe -k install
    Start-Service Apache2.4

    Write-Host "Apache instalado y ejecutándose en puerto $Port" -ForegroundColor Green
}