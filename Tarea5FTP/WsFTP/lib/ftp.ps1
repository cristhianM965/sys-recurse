function Instalar-RolFTP {
    Write-Host "Instalando IIS + FTP..." -ForegroundColor Yellow

    $features = @(
        "Web-Server",
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Static-Content",
        "Web-Mgmt-Tools",
        "Web-Mgmt-Console",
        "Web-Ftp-Server",
        "Web-Ftp-Service",
        "Web-Ftp-Ext"
    )

    foreach ($feature in $features) {
        $estado = Get-WindowsFeature -Name $feature
        if (-not $estado.Installed) {
            Install-WindowsFeature -Name $feature -IncludeManagementTools | Out-Null
            Write-Host "Instalado: $feature" -ForegroundColor Green
        } else {
            Write-Host "Ya instalado: $feature" -ForegroundColor Cyan
        }
    }

    Import-Module WebAdministration -ErrorAction Stop
}

function Crear-SitioFTP {
    Write-Host "Creando o verificando sitio FTP..." -ForegroundColor Yellow

    if (-not (Get-Website -Name $Global:SiteName -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name $Global:SiteName -Port $Global:PuertoFTP -PhysicalPath $Global:FtpRoot -Force | Out-Null
        Write-Host "Sitio FTP creado." -ForegroundColor Green
    } else {
        Write-Host "El sitio FTP ya existe." -ForegroundColor Cyan
    }
}

function Configurar-AutenticacionFTP {
    Write-Host "Configurando autenticación FTP..." -ForegroundColor Yellow

    Set-ItemProperty "IIS:\Sites\$($Global:SiteName)" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$($Global:SiteName)" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
}

function Limpiar-ReglasAutorizacionFTP {
    $filter = "system.ftpServer/security/authorization"
    $rules = Get-WebConfiguration -Filter $filter -PSPath "IIS:\" -Location $Global:SiteName

    if ($rules.Collection.Count -gt 0) {
        for ($i = $rules.Collection.Count - 1; $i -ge 0; $i--) {
            Remove-WebConfigurationProperty `
                -PSPath "IIS:\" `
                -Location $Global:SiteName `
                -Filter $filter `
                -Name "." `
                -AtIndex $i
        }
    }
}

function Configurar-ReglasFTP {
    Write-Host "Configurando reglas FTP..." -ForegroundColor Yellow

    Limpiar-ReglasAutorizacionFTP

    Add-WebConfiguration `
        -PSPath "IIS:\" `
        -Location $Global:SiteName `
        -Filter "system.ftpServer/security/authorization" `
        -Value @{
            accessType  = "Allow"
            users       = "anonymous"
            permissions = "Read"
        }

    Add-WebConfiguration `
        -PSPath "IIS:\" `
        -Location $Global:SiteName `
        -Filter "system.ftpServer/security/authorization" `
        -Value @{
            accessType  = "Allow"
            roles       = "Users"
            permissions = "Read, Write"
        }
}

function Configurar-AislamientoUsuarios {
    Write-Host "Configurando aislamiento de usuarios FTP..." -ForegroundColor Yellow

    Set-ItemProperty "IIS:\Sites\$($Global:SiteName)" `
        -Name ftpServer.userIsolation.mode `
        -Value "IsolateRootDirectoryOnly"
}

function Reiniciar-SitioFTP {
    Write-Host "Reiniciando sitio FTP..." -ForegroundColor Yellow

    Stop-Website -Name $Global:SiteName -ErrorAction SilentlyContinue
    Start-Website -Name $Global:SiteName
}

function Configurar-FTPCompleto {
    Instalar-RolFTP
    Crear-EstructuraBase
    Configurar-PermisosBase
    Crear-SitioFTP
    Configurar-AutenticacionFTP
    Configurar-ReglasFTP
    Configurar-AislamientoUsuarios
    Reiniciar-SitioFTP

    Write-Host "FTP configurado correctamente." -ForegroundColor Green
}