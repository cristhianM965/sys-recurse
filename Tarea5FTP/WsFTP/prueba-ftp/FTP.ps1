#Importacion de modulos

$modulosPath = Join-Path $PSScriptRoot "..\prueba-ftp"
. (Join-Path $modulosPath "usuarios.ps1")
. (Join-Path $modulosPath "validadores.ps1")

Import-Module WebAdministration -Force

#Verificacion Inicial del servicio FTP 
$serviceName = "FTPSVC"
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($null -ne $service) {
    Write-Host "El servicio FTP ya está instalado."
} else {
    Write-Host "El servicio FTP no está instalado" -ForegroundColor Yellow
    #Instalacion de los servcios para el servidor FTP
    Write-Host "Instalando servicios necesarios para el servidor FTP..." -ForegroundColor Yellow
    Install-WindowsFeature -Name Web-Server, Web-Ftp-Server, Web-Ftp-Service, Web-Ftp-Ext, Web-Scripting-Tools -IncludeManagementTools

    # Firewall rule
    Write-Host "Creando regla de firewall..." -ForegroundColor Yellow
    New-NetFirewallRule -DisplayName "FTP" -Direction Inbound -LocalPort 21 -Protocol TCP -Action Allow

    #Creacion de los grupos
    Write-Host "Creando grupos necesarios para el servidor FTP..." -ForegroundColor Yellow
    New-LocalGroup -Name "reprobados" -Description "Grupo de reprobados"
    New-LocalGroup -Name "recursadores" -Description "Grupo de recursadores"

    #Creacion de carpeta raiz del FTP
    Write-Host "Creando carpeta principal del FTP..." -ForegroundColor Yellow
    $ftpPath = "C:\FTP"
    New-Item -Path $ftpPath -ItemType Directory

    #Creacion de un sitio FTP
    Write-Host "Creando sitio FTP..." -ForegroundColor Yellow
    New-webSite -Name "FTP" -Port 21 -PhysicalPath $ftpPath
    Write-Host "Ajustando los enlaces del sitio..." -ForegroundColor Yellow
    Set-WebBinding -Name "FTP" -BindingInformation "*:21:" -PropertyName Port -Value 80
    New-WebBinding -Name "FTP" -Protocol "ftp" -IPAddress "*" -Port 21

    #Creacion de la propiedad de aislamiento
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpserver.userIsolation.mode" -Value 3

    #Creando carpetas escenciales del FTP
    Write-Host "Creando carpetas de reprobados" -ForegroundColor Yellow
    $reprobadosPath = "C:\FTP\reprobados"
    New-Item -Path $reprobadosPath -ItemType Directory

    Write-Host "Creando carpetas de recursadores" -ForegroundColor Yellow
    $recursadoresPath = "C:\FTP\recursadores"
    New-Item -Path $recursadoresPath -ItemType Directory
    
    Write-Host "Creando carpetas de localusers" -ForegroundColor Yellow
    $localuserPath = "C:\FTP\LocalUser"
    New-Item -Path $localuserPath -ItemType Directory

    Write-Host "Creando carpeta general" -ForegroundColor Yellow
    $generalPath = "C:\FTP\LocalUser\Public"
    New-Item -Path $generalPath -ItemType Directory
    New-Item -Path "$generalPath\General" -ItemType Directory

    #Configuracion de los permisos de las carpetas

    # Permitir acceso total a los grupos en sus carpetas
    Write-Host "Asignando los permisos para el grupo de reprobados....." -ForegroundColor Yellow
    icacls $reprobadosPath /grant "reprobados:(OI)(CI)F" /inheritance:r

    Write-Host "Asignando los permisos para el grupo de recursadores....." -ForegroundColor Yellow
    icacls $recursadoresPath /grant "recursadores:(OI)(CI)F" /inheritance:r

    # Permitir acceso total a los usuarios en la carpeta general
    Write-Host "Asignando los permisos para todos en la carpeta publica....." -ForegroundColor Yellow
    icacls $generalPath /grant "Todos:(OI)(CI)F" /inheritance:r
    icacls $generalPath /grant "IUSR:(OI)(CI)F" /inheritance:r
    icacls "$generalPath\General" /grant "Todos:(OI)(CI)F" /inheritance:r
    icacls "$generalPath\General" /grant "IUSR:(OI)(CI)F" /inheritance:r
    icacls $ftpPath /grant "Todos:(OI)(CI)F" /inheritance:r

    Write-Host "Asignando los permisos para LocalUser..." -ForegroundColor Yellow
    icacls $localuserPath /grant "Todos:(OI)(CI)F" /inheritance:r

    #Ajustando autenticaciones con el set Property
    Write-Host "Ajustando la autenticacion desde ItemProperty............." -ForegroundColor Yellow
    $sitioFTP = "FTP"
    Set-ItemProperty "IIS:\Sites\$sitioFTP" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty "IIS:\Sites\$sitioFTP" -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true

    Write-Host "Ajustando la autenticacion desde WebConfiguration........" -ForegroundColor Yellow
    Add-WebConfigurationProperty -filter "/system.ftpServer/security/authentication/basicAuthentication" -name enabled -value true -PSPath "IIS:\Sites\$sitioFTP"
    Add-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" -name enabled -Value true -PSPath "IIS:\Sites\$sitioFTP"

    Write-Host "Ajustando los AccesType de los grupos y todos....." -ForegroundColor Yellow
    $FTPSitePath = "IIS:\Sites\$sitioFTP"
    $BasicAuth = 'ftpServer.security.authentication.basicAuthentication.enabled'
    Set-ItemProperty -Path $FTPSitePath -Name $BasicAuth -Value $true 
    $param =@{
        Filter = "/system.ftpServer/security/authorization"
        value = @{
            accessType = "Allow"
            roles = "recursadores"
            permision = 1
        }
        PSPath = 'IIS:\'
        Location = $sitioFTP
    }
    $param2 =@{
        Filter = "/system.ftpServer/security/authorization"
        value = @{
            accessType = "Allow"
            roles = "reprobados"
            permision = 1
        }
        PSPath = 'IIS:\'
        Location = $sitioFTP
    }
    $param3 =@{
        Filter = "/system.ftpServer/security/authorization"
        value = @{
            accessType = "Allow"
            roles = "*"
            permision = "Read, Write"
        }
        PSPath = 'IIS:\'
        Location = $sitioFTP
    }
    Add-WebConfiguration @param
    Add-WebConfiguration @param2
    Add-WebConfiguration @param3

    $SSLPolicy = @(
        'ftpServer.security.ssl.controlChannelPolicy',
        'ftpServer.security.ssl.dataChannelPolicy'
    )
    Write-Host "Ajustando SSL del sitio FTP...." -ForegroundColor Yellow
    Set-ItemProperty "IIS:\Sites\$sitioFTP" -name $SSLPolicy[0] -value 0
    Set-ItemProperty "IIS:\Sites\$sitioFTP" -name $SSLPolicy[1] -value 0

    # Reiniciar FTP para aplicar cambios
    Write-Host "Reiniciando el servicio de FTP....." -ForegroundColor Yellow
    Restart-Service -Name FTPSVC
    Restart-Service W3SVC
    Restart-WebItem "IIS:\Sites\$sitioFTP" -Verbose

    #Mostrar que esta corriendo el servicio
    Write-Host "Verificando si el servicio esta corriendo...." -ForegroundColor Yellow
    Get-Service -Name FTPSVC

    #Mensaje de finalizacion
    Write-Host "Servidor FTP configurado correctamente" -ForegroundColor Green
}
do{
    Write-Host "¿Qué desea hacer?"
    Write-Host "[1].-Gestor de usuarios"
    Write-Host "[2].-Salir"
    $opcion = Read-Host "<1/2>" 

    if($opcion -eq 1){
        gestor_usuarios
        Restart-Service -Name FTPSVC
        Restart-Service W3SVC
        Restart-WebItem "IIS:\Sites\FTP" -Verbose
    }
    if($opcion -eq 2){
        Write-Host "Saliendo..."
        continue
    }
    else{
        Write-Host "Opción no válida" -ForegroundColor Red
    }

}while($opcion -ne 1 -and $opcion -ne 2)