function Validar-TextoNoVacio {
    param([string]$Texto)
    return -not [string]::IsNullOrWhiteSpace($Texto)
}

function Validar-SinEspacios {
    param([string]$Texto)
    return ($Texto -notmatch "\s")
}

function Validar-LongitudMaxima {
    param([string]$Texto, [int]$Max = 20)
    return ($Texto.Length -le $Max)
}

function Validar-SoloAlfanumerico {
    param([string]$Texto)
    return ($Texto -match '^[a-zA-Z0-9]+$')
}

function Validar-Contrasena {
    param(
        [string]$Contrasena,
        [string]$Usuario
    )

    if ([string]::IsNullOrWhiteSpace($Contrasena)) { return $false }
    if ($Contrasena.Length -lt 8 -or $Contrasena.Length -gt 12) { return $false }
    if ($Contrasena -notmatch '[A-Z]') { return $false }
    if ($Contrasena -notmatch '[0-9]') { return $false }
    if ($Usuario -and $Contrasena.ToLower().Contains($Usuario.ToLower())) { return $false }

    return $true
}

function Validar-Grupo {
    param([string]$Grupo)
    return ($Grupo -eq $Global:Grupo1 -or $Grupo -eq $Global:Grupo2)
}

function Pedir-GrupoValido {
    do {
        $grupo = (Read-Host "Grupo [reprobados/recursadores]").ToLower()
        if (Validar-Grupo $grupo) {
            return $grupo
        }
        Write-Host "Grupo inválido." -ForegroundColor Red
    } while ($true)
}

function Pedir-UsuarioValido {
    do {
        $usuario = Read-Host "Nombre de usuario"
        if (-not (Validar-TextoNoVacio $usuario)) {
            Write-Host "No puede estar vacío." -ForegroundColor Red
            continue
        }
        if (-not (Validar-SinEspacios $usuario)) {
            Write-Host "No debe contener espacios." -ForegroundColor Red
            continue
        }
        if (-not (Validar-LongitudMaxima $usuario 20)) {
            Write-Host "Máximo 20 caracteres." -ForegroundColor Red
            continue
        }
        if (-not (Validar-SoloAlfanumerico $usuario)) {
            Write-Host "Solo letras y números." -ForegroundColor Red
            continue
        }
        return $usuario
    } while ($true)
}

function Pedir-ContrasenaValida {
    param([string]$Usuario)

    do {
        $password = Read-Host "Contraseña (8-12, 1 mayúscula, 1 número)"
        if (Validar-Contrasena -Contrasena $password -Usuario $Usuario) {
            return $password
        }
        Write-Host "Contraseña inválida." -ForegroundColor Red
    } while ($true)
}