function Read-Number {
    param([string]$Message)

    while ($true) {
        $value = Read-Host $Message
        if ($value -match '^\d+$') {
            return [int]$value
        }
        Write-Host "Entrada inválida."
    }
}

function Read-Port {
    while ($true) {
        $port = Read-Number "Puerto"
        if ($port -lt 1024 -or $port -gt 65535) {
            Write-Host "Usa un puerto entre 1024 y 65535."
            continue
        }

        if ($port -in 21,22,23,25,53,67,68,69,80,110,123,135,137,138,139,143,389,443,445,587,993,995,1433,1521,3306,3389,5432) {
            Write-Host "Puerto reservado, elige otro."
            continue
        }

        if (-not (Test-PortFree $port)) {
            Write-Host "Puerto ocupado."
            continue
        }

        return $port
    }
}

function Test-PortFree {
    param([int]$Port)

    $conn = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction SilentlyContinue
    return (-not $conn.TcpTestSucceeded)
}

function Open-FirewallPort {
    param([int]$Port)

    New-NetFirewallRule `
        -DisplayName "HTTP-$Port" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $Port `
        -Action Allow `
        -ErrorAction SilentlyContinue | Out-Null
}

function Remove-FirewallPort {
    param([int]$Port)

    Get-NetFirewallRule -DisplayName "HTTP-$Port" -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

function Validate-HTTP {
    param([int]$Port)

    Write-Host "`nValidación sugerida:"
    Write-Host "curl -I http://localhost:$Port`n"

    try {
        curl.exe -I "http://localhost:$Port"
    } catch {
        Write-Host "No se pudo validar el puerto $Port"
    }
}

function Ensure-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        return
    }

    Write-Host "Chocolatey no está instalado. Instalando Chocolatey..."

    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    $env:Path += ";C:\ProgramData\chocolatey\bin"

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw "No se pudo instalar Chocolatey."
    }
}

function Get-ChocoVersions {
    param([string]$PackageName)

    Ensure-Chocolatey

    $versions = @()

    $lines = choco search $PackageName --exact --all-versions -r 2>$null

    foreach ($line in $lines) {
        if ($line -match '^\s*[^|]+\|(.+?)\s*$') {
            $versions += $matches[1].Trim()
        }
    }

    if (-not $versions -or $versions.Count -eq 0) {
        $lines = choco info $PackageName --all-versions -r 2>$null

        foreach ($line in $lines) {
            if ($line -match '^\s*[^|]+\|(.+?)\s*$') {
                $versions += $matches[1].Trim()
            }
        }
    }

    return ($versions | Select-Object -Unique)
}

function Select-VersionFromList {
    param(
        [string]$ServiceName,
        [string[]]$Versions
    )

    if (-not $Versions -or $Versions.Count -eq 0) {
        throw "No se encontraron versiones para $ServiceName."
    }

    Write-Host "`nVersiones disponibles para ${ServiceName}:"
    for ($i = 0; $i -lt $Versions.Count; $i++) {
        Write-Host "[$($i+1)] $($Versions[$i])"
    }

    while ($true) {
        $opt = Read-Number "Elige una versión"
        if ($opt -ge 1 -and $opt -le $Versions.Count) {
            return $Versions[$opt - 1]
        }
        Write-Host "Opción inválida."
    }
}

function Stop-ProcessIfRunning {
    param([string]$Name)

    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}