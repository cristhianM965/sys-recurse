function Existe-UsuarioLocal {
    param([string]$Usuario)
    return ($null -ne (Get-LocalUser -Name $Usuario -ErrorAction SilentlyContinue))
}

function Existe-GrupoLocal {
    param([string]$Grupo)
    return ($null -ne (Get-LocalGroup -Name $Grupo -ErrorAction SilentlyContinue))
}

function Asegurar-Grupos {
    foreach ($grupo in @($Global:Grupo1, $Global:Grupo2)) {
        if (-not (Existe-GrupoLocal $grupo)) {
            New-LocalGroup -Name $grupo | Out-Null
            Write-Host "Grupo creado: $grupo" -ForegroundColor Green
        } else {
            Write-Host "Grupo ya existente: $grupo" -ForegroundColor Cyan
        }
    }
}

function Crear-UsuarioFTP {
    param(
        [string]$Usuario,
        [string]$Contrasena,
        [string]$Grupo
    )

    if (Existe-UsuarioLocal $Usuario) {
        Write-Host "El usuario ya existe." -ForegroundColor Red
        return
    }

    $securePassword = ConvertTo-SecureString $Contrasena -AsPlainText -Force

    New-LocalUser `
        -Name $Usuario `
        -Password $securePassword `
        -PasswordNeverExpires `
        -AccountNeverExpires `
        -UserMayNotChangePassword:$false | Out-Null

    Add-LocalGroupMember -Group $Grupo -Member $Usuario
    Add-LocalGroupMember -Group "Users" -Member $Usuario -ErrorAction SilentlyContinue

    Crear-EstructuraUsuario -Usuario $Usuario -Grupo $Grupo

    Write-Host "Usuario creado correctamente: $Usuario" -ForegroundColor Green
}

function Crear-UsuariosInteractivo {
    $cantidad = Read-Host "¿Cuántos usuarios desea crear?"
    if ($cantidad -notmatch '^\d+$') {
        Write-Host "Cantidad inválida." -ForegroundColor Red
        return
    }

    for ($i = 1; $i -le [int]$cantidad; $i++) {
        Write-Host "`nUsuario $i de $cantidad" -ForegroundColor Yellow

        do {
            $usuario = Pedir-UsuarioValido
            if (Existe-UsuarioLocal $usuario) {
                Write-Host "Ese usuario ya existe." -ForegroundColor Red
                $usuario = $null
            }
        } while (-not $usuario)

        $password = Pedir-ContrasenaValida -Usuario $usuario
        $grupo = Pedir-GrupoValido

        Crear-UsuarioFTP -Usuario $usuario -Contrasena $password -Grupo $grupo
    }
}

function Cambiar-GrupoUsuario {
    $usuario = Read-Host "Usuario a cambiar de grupo"

    if (-not (Existe-UsuarioLocal $usuario)) {
        Write-Host "El usuario no existe." -ForegroundColor Red
        return
    }

    $nuevoGrupo = Pedir-GrupoValido

    Remove-LocalGroupMember -Group $Global:Grupo1 -Member $usuario -ErrorAction SilentlyContinue
    Remove-LocalGroupMember -Group $Global:Grupo2 -Member $usuario -ErrorAction SilentlyContinue

    Add-LocalGroupMember -Group $nuevoGrupo -Member $usuario -ErrorAction SilentlyContinue
    Actualizar-EstructuraGrupoUsuario -Usuario $usuario -NuevoGrupo $nuevoGrupo

    Write-Host "Grupo actualizado correctamente." -ForegroundColor Green
}

function Eliminar-UsuarioFTP {
    $usuario = Read-Host "Usuario a eliminar"

    if (-not (Existe-UsuarioLocal $usuario)) {
        Write-Host "El usuario no existe." -ForegroundColor Red
        return
    }

    Remove-LocalGroupMember -Group $Global:Grupo1 -Member $usuario -ErrorAction SilentlyContinue
    Remove-LocalGroupMember -Group $Global:Grupo2 -Member $usuario -ErrorAction SilentlyContinue

    Remove-LocalUser -Name $usuario

    $userRoot = Join-Path $Global:UsersPath $usuario
    if (Test-Path $userRoot) {
        Remove-Item $userRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Usuario eliminado correctamente." -ForegroundColor Green
}

function Listar-UsuariosFTP {
    Write-Host "`nUsuarios locales del sistema:" -ForegroundColor Yellow
    Get-LocalUser | Select-Object Name, Enabled | Format-Table -AutoSize
}