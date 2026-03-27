function Test-PortAvailable {
    param([int]$Port)

    $used = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue

    if ($used) {
        Write-Host "Puerto en uso"
        return $false
    }

    return $true
}