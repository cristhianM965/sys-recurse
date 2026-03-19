function Install-IIS {

    $port = Read-Number "Puerto IIS"

    if (-not (Test-PortFree $port)) {
        Write-Host "Puerto ocupado"
        return
    }

    Write-Host "Instalando IIS..."

    Install-WindowsFeature -Name Web-Server -IncludeManagementTools

    # 🔥 IMPORTAR DESPUÉS DE INSTALAR
    Import-Module WebAdministration

    # Cambiar puerto (forma segura)
    Set-WebBinding `
        -Name "Default Web Site" `
        -PropertyName Port `
        -Value $port

    # Seguridad básica
    Remove-WebConfigurationProperty `
        -pspath 'MACHINE/WEBROOT/APPHOST' `
        -filter "system.webServer/httpProtocol/customHeaders" `
        -name "." `
        -AtElement @{name='X-Powered-By'} `
        -ErrorAction SilentlyContinue

    Open-FirewallPort $port

    Restart-Service W3SVC

    Validate-HTTP $port
}