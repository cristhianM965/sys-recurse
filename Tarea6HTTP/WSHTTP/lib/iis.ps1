Import-Module WebAdministration

function Install-IIS {

    $port = Read-Number "Puerto IIS"

    if (-not (Test-PortFree $port)) {
        Write-Host "Puerto ocupado"
        return
    }

    Write-Host "Instalando IIS..."

    Enable-WindowsOptionalFeature `
        -Online `
        -FeatureName IIS-WebServerRole `
        -All `
        -NoRestart

    # Cambiar puerto
    Set-WebBinding `
        -Name "Default Web Site" `
        -BindingInformation "*:$port:" `
        -PropertyName Port `
        -Value $port

    # Seguridad básica
    Remove-WebConfigurationProperty `
        -pspath 'MACHINE/WEBROOT/APPHOST' `
        -filter "system.webServer/httpProtocol/customHeaders" `
        -name "." `
        -AtElement @{name='X-Powered-By'} `
        -ErrorAction SilentlyContinue

    # Firewall
    Open-FirewallPort $port

    Restart-Service W3SVC

    Validate-HTTP $port
}