function Read-Number {
    param($msg)

    while ($true) {
        $val = Read-Host $msg
        if ($val -match '^\d+$') { return [int]$val }
        Write-Host "Entrada inválida"
    }
}

function Test-PortFree {
    param($port)
    return -not (Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded
}

function Open-FirewallPort {
    param($port)

    New-NetFirewallRule `
        -DisplayName "HTTP-$port" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $port `
        -Action Allow `
        -ErrorAction SilentlyContinue
}

function Validate-HTTP {
    param($port)

    Write-Host "Validación:"
    try {
        Invoke-WebRequest "http://localhost:$port" -UseBasicParsing | Out-Null
        Write-Host "Servidor activo en puerto $port"
    } catch {
        Write-Host "Error al validar"
    }
}