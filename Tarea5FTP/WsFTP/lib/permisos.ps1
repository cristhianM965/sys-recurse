function Asegurar-Carpeta {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Crear-EstructuraBase {
    Write-Host "Creando estructura base..." -ForegroundColor Yellow

    Asegurar-Carpeta $Global:FtpRoot
    Asegurar-Carpeta $Global:GeneralPath
    Asegurar-Carpeta $Global:RepPath
    Asegurar-Carpeta $Global:RecPath
    Asegurar-Carpeta $Global:UsersPath
}

function Configurar-PermisosBase {
    Write-Host "Configurando permisos base..." -ForegroundColor Yellow

    icacls $Global:FtpRoot /inheritance:r | Out-Null
    icacls $Global:FtpRoot /grant "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" | Out-Null

    icacls $Global:GeneralPath /inheritance:r | Out-Null
    icacls $Global:GeneralPath /grant "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" | Out-Null
    icacls $Global:GeneralPath /grant "IUSR:(OI)(CI)RX" | Out-Null
    icacls $Global:GeneralPath /grant "Usuarios:(OI)(CI)M" | Out-Null

    icacls $Global:RepPath /inheritance:r | Out-Null
    icacls $Global:RepPath /grant "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "$($Global:Grupo1):(OI)(CI)M" | Out-Null

    icacls $Global:RecPath /inheritance:r | Out-Null
    icacls $Global:RecPath /grant "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "$($Global:Grupo2):(OI)(CI)M" | Out-Null

    icacls $Global:UsersPath /inheritance:r | Out-Null
    icacls $Global:UsersPath /grant "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" | Out-Null
}

function Crear-EstructuraUsuario {
    param(
        [string]$Usuario,
        [string]$Grupo
    )

    $userRoot = Join-Path $Global:UsersPath $Usuario
    $userHome = Join-Path $userRoot $Usuario
    $linkGeneral = Join-Path $userRoot "general"
    $linkGrupo = Join-Path $userRoot $Grupo

    Asegurar-Carpeta $userRoot
    Asegurar-Carpeta $userHome

    if (Test-Path $linkGeneral) {
        Remove-Item $linkGeneral -Force -Recurse -ErrorAction SilentlyContinue
    }

    if (Test-Path $linkGrupo) {
        Remove-Item $linkGrupo -Force -Recurse -ErrorAction SilentlyContinue
    }

    cmd /c "mklink /J `"$linkGeneral`" `"$($Global:GeneralPath)`"" | Out-Null

    if ($Grupo -eq $Global:Grupo1) {
        cmd /c "mklink /J `"$linkGrupo`" `"$($Global:RepPath)`"" | Out-Null
    }
    else {
        cmd /c "mklink /J `"$linkGrupo`" `"$($Global:RecPath)`"" | Out-Null
    }

    icacls $userRoot /inheritance:r | Out-Null
    icacls $userRoot /grant "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "${Usuario}:(OI)(CI)M" | Out-Null

    icacls $userHome /inheritance:r | Out-Null
    icacls $userHome /grant "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "${Usuario}:(OI)(CI)M" | Out-Null
}

function Actualizar-EstructuraGrupoUsuario {
    param(
        [string]$Usuario,
        [string]$NuevoGrupo
    )

    $userRoot = Join-Path $Global:UsersPath $Usuario
    $linkRep = Join-Path $userRoot $Global:Grupo1
    $linkRec = Join-Path $userRoot $Global:Grupo2

    if (Test-Path $linkRep) {
        Remove-Item $linkRep -Force -Recurse -ErrorAction SilentlyContinue
    }

    if (Test-Path $linkRec) {
        Remove-Item $linkRec -Force -Recurse -ErrorAction SilentlyContinue
    }

    if ($NuevoGrupo -eq $Global:Grupo1) {
        cmd /c "mklink /J `"$linkRep`" `"$($Global:RepPath)`"" | Out-Null
    }
    else {
        cmd /c "mklink /J `"$linkRec`" `"$($Global:RecPath)`"" | Out-Null
    }
}