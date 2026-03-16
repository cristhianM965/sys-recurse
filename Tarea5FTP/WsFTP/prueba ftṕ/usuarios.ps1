
Join-Path $PSScriptRoot ".\prueba ftp\validadores.ps1"
Import-Module WebAdministration -Force
function gestor_usuarios{
    
    do{
        Write-Host "--Menu de usuarios--"
        Write-Host "[1].- Crear usuario"
        Write-Host "[2].- Eliminar usuario"
        Write-Host "[3].- Cambiar de grupo usuario"
        Write-Host "[4].- Salir"
        $opc = Read-Host ">"

        switch ($opc) {
            1 {
                #--------------------------------------
                #            Crear usuarios
                #--------------------------------------
                do{
                    $usuario = ""
                    do{
                        $usuario = Read-Host "Ingrese el nombre del usuario"

                        $vu1 = validar_textos_nulos -texto $usuario
                        if($vu1 -eq $false){
                            Write-Host "Error: El nombre de usuario no puede estar vacío" -ForegroundColor Red
                            continue
                        }

                        $vu2 = validar_espacios -usuario $usuario
                        if($vu2 -eq $false){
                            Write-Host "Error: El nombre de usuario no puede contener espacios" -ForegroundColor Red
                            continue
                        }

                        $vu3 = validar_longitud_maxima -texto $usuario
                        if($vu3 -eq $false){
                            Write-Host "Error: El usuario no puede se maximo de 20 caracteres" -ForegroundColor Red
                            continue
                        }

                        $vu4 = validar_sin_caracteres_especiales -texto $usuario
                        if($vu4 -eq $false){
                            Write-Host "Error: El usuario no puede tener caracteres especiales" -ForegroundColor Red
                            continue
                        }

                        $vu5 = validar_usuario_existente -usuario $usuario
                        if($vu5 -eq $true){
                            Write-Host "Error: El usuario ya existe" -ForegroundColor Red
                            continue
                        }

                    }While($vu1 -eq $false -or $vu2 -eq $false -or $vu3 -eq $false -or $vu4 -eq $false -or $vu5 -eq $true)

                    $password = ""
                    do{            
                        $password = Read-Host "Ingresa la contrasena"

                        $vc1 = validar_textos_nulos -texto $password
                        if($vc1 -eq $false){
                            Write-Host "Error: La contrasena no puede estar vacía" -ForegroundColor Red
                            continue
                        }
                        
                        $vc2 = validar_espacios -usuario $password
                        if($vc2 -eq $false){
                            Write-Host "Error: La contrasena no puede contener espacios" -ForegroundColor Red
                            continue
                        }

                        $vc3 = validar_contrasena -contrasena $password -usuario $usuario
                        if($vc3 -eq $false){
                            Write-Host "Error: La contrasena debe ser entre 8 y 12 caracteres,llevar una letra mayúscula y un número" -ForegroundColor Red
                            continue
                        }

                    }While($vc1 -eq $false -or $vc2 -eq $false -or $vc3 -eq $false)

                    Write-Host "Creando usuario....." -ForegroundColor Green
                    try{
                        New-LocalUser -Name $usuario -Password (ConvertTo-SecureString -String $password -AsPlainText -Force) -FullName "$($usuario) EI" -Description "Usuario" -PasswordNeverExpires 
                        Add-LocalGroupMember -Group "Usuarios" -Member $usuario
                        Add-LocalGroupMember -Group "IIS_IUSRS" -Member $usuario
                        Write-Host "Usuario creado correctamente" -ForegroundColor Green
                    }catch{
                        Write-Host "Error Inesperado en la creacion del usuario." -ForegroundColor Red
                    }

                    #Creacion de carpeta personal
                    $userpath = "C:\FTP\LocalUser\$usuario"
                    New-Item -Path $userpath -ItemType Directory
                    New-Item -Path "$userpath\$usuario" -ItemType Directory
                    
                    $generalPath = "C:\FTP\LocalUser\Public"
                    New-Item -ItemType Junction -Path "$userpath\general" -Target $generalPath

                    #Asignacion de permisos
                    # Configurar permisos para que SOLO el usuario y su grupo accedan a su carpeta
                    icacls $userpath /grant "$($usuario):(OI)(CI)F" /inheritance:r
                    
                    #Agregar el usuario a un grupo
                    do{
                        Write-Host "A que grupo desea agregarlo?"
                        Write-Host "[1].- reprobados"
                        Write-Host "[2].- recursadores"
                        $grupo = Read-Host ">"

                        switch ($grupo) {
                            1 {
                                Add-LocalGroupMember -Group "reprobados" -Member $usuario
                                Write-Host "Usuario agregado al grupo reprobados" -ForegroundColor Green
                                $reprobadosPath = "C:\FTP\reprobados"
                                New-Item -ItemType Junction -Path "$userpath\reprobados" -Target $reprobadosPath
                            }
                            2 {
                                Add-LocalGroupMember -Group "recursadores" -Member $usuario
                                Write-Host "Usuario agregado al grupo recursadores" -ForegroundColor Green
                                $recursadoresPath = "C:\FTP\recursadores"
                                New-Item -ItemType Junction -Path "$userpath\recursadores" -Target $recursadoresPath
                            }
                            Default {
                                Write-Host "Opción no válida, ingrese 1 o 2" -ForegroundColor Red
                            }
                        }
                    }while($grupo -ne 1 -and $grupo -ne 2)

                    do{
                        Write-Host "Desea crear otro usuario? "
                        $ver= Read-Host "Si(S) o No(N): "
                        $ver=$ver.ToUpper()
                        if($ver -ne "S" -and $ver -ne "N"){
                            Write-Host "Favor de ingresar S o N" -ForegroundColor Red
                        }
                    }while($ver -ne "S" -and $ver -ne "N")
                }while($ver -eq "S")
                Restart-Service -Name FTPSVC
                Restart-Service W3SVC
                Restart-WebItem "IIS:\Sites\FTP" -Verbose
            }
            2 { 
                #--------------------------------------
                #          Eliminar usuarios
                #--------------------------------------
                do{
                    $usuario = ""
                    do{
                        $usuario = Read-Host "Ingrese el nombre del usuario a eliminar"
                        
                        if($usuario -match "[0-9]"){
                            Write-Host "El usuario no puede tener numeros"
                            continue
                        }

                        $vu1 = validar_textos_nulos -texto $usuario
                        if($vu1 -eq $false){
                            Write-Host "Error: Los usuarios no son vacios" -ForegroundColor Red
                            continue
                        }

                        $vu2 = validar_espacios -usuario $usuario
                        if($vu2 -eq $false){
                            Write-Host "Error: Los usuarios no contienen espacios" -ForegroundColor Red
                            continue
                        }

                        $vu3 = validar_longitud_maxima -texto $usuario
                        if($vu3 -eq $false){
                            Write-Host "Error: Los usuarios no tienen mas de 20 caracteres" -ForegroundColor Red
                            continue
                        }

                        $vu4 = validar_sin_caracteres_especiales -texto $usuario
                        if($vu4 -eq $false){
                            Write-Host "Error: Los usuarios no tienen caracteres especiales" -ForegroundColor Red
                            continue
                        }

                        $vu5 = validar_usuario_existente -usuario $usuario
                        if($vu3 -eq $false){
                            Write-Host "Error: El usuario no existe" -ForegroundColor Red
                            continue
                        }
                    }While($vu1 -eq $false -or $vu2 -eq $false -or $vu3 -eq $false -or $vu4 -eq $false -or $vu5 -eq $false)

                    Write-Host "Eliminando usuario....." -ForegroundColor Green
                    try{
                        Remove-LocalUser -Name $usuario -Confirm:$false
                        Remove-Item -path "C:\FTP\LocalUser\$usuario" -recurse
                        Write-Host "Usuario eliminado correctamente" -ForegroundColor Green
                    }
                    catch{
                        Write-Host "Error inesperado" -ForegroundColor Red
                    }
                    do{
                        Write-Host "Desea eliminar otro usuario? "
                        $ver= Read-Host "Si(S) o No(N): "
                        $ver=$ver.ToUpper()
                        if($ver -ne "S" -and $ver -ne "N"){
                            Write-Host "Favor de ingresar S o N" -ForegroundColor Red
                        }
                    }while($ver -ne "S" -and $ver -ne "N")
                }while($ver -eq "S")
                Restart-Service -Name FTPSVC
                Restart-Service W3SVC
                Restart-WebItem "IIS:\Sites\FTP" -Verbose
            }
            3 { 
                #---------------------------------------------------------
                #           Editar grupo del usuario
                #---------------------------------------------------------
                do{
                    $usuario = ""
                    do{
                        $usuario = Read-Host "Ingrese el nombre del usuario para modificar"

                        $vu1 = validar_textos_nulos -texto $usuario
                        if($vu1 -eq $false){
                            Write-Host "Error: Los usuarios no son vacios" -ForegroundColor Red
                            continue
                        }

                        $vu2 = validar_espacios -usuario $usuario
                        if($vu2 -eq $false){
                            Write-Host "Error: Los usuarios no contienen espacios" -ForegroundColor Red
                            continue
                        }

                        $vu3 = validar_longitud_maxima -texto $usuario
                        if($vu3 -eq $false){
                            Write-Host "Error: Los usuarios no tienen mas de 20 caracteres" -ForegroundColor Red
                            continue
                        }

                        $vu4 = validar_sin_caracteres_especiales -texto $usuario
                        if($vu4 -eq $false){
                            Write-Host "Error: Los usuarios no tienen caracteres especiales" -ForegroundColor Red
                            continue
                        }

                        $vu5 = validar_usuario_existente -usuario $usuario
                        if($vu3 -eq $false){
                            Write-Host "Error: El usuario no existe" -ForegroundColor Red
                            continue
                        }
                    }While($vu1 -eq $false -or $vu2 -eq $false -or $vu3 -eq $false -or $vu4 -eq $false -or $vu5 -eq $false)

                    try {
                        
                        $gruposActuales = $null

                        if (Get-LocalGroupMember -Group "reprobados" -Member $usuario -ErrorAction SilentlyContinue) {
                            $gruposActuales = "reprobados"
                        } elseif (Get-LocalGroupMember -Group "recursadores" -Member $usuario -ErrorAction SilentlyContinue) {
                            $gruposActuales = "recursadores"
                        } else {
                            $gruposActuales = "ninguno"
                        }
  
                        if ($gruposActuales.Count -eq 0) {
                            Write-Host "El usuario '$usuario' no pertenece a ningún grupo local." -ForegroundColor Yellow
                            return
                        }
                
                        # Determinar el nuevo grupo
                        if ($gruposActuales -contains "reprobados") {
                            $nuevoGrupo = "recursadores"
                            $grupoAntiguo = "reprobados"
                        } elseif ($gruposActuales -contains "recursadores") {
                            $nuevoGrupo = "reprobados"
                            $grupoAntiguo = "recursadores"
                        } else {
                            Write-Host "El usuario '$usuario' no pertenece a 'reprobados' ni 'recursadores'." -ForegroundColor Yellow
                            return
                        }
                
                        # Solicitar confirmación
                        $confirmacion = Read-Host "Desea cambiar el usuario '$usuario' de '$grupoAntiguo' a '$nuevoGrupo'? (S/N)"
                        $confirmacion = $confirmacion.ToUpper()
                        
                        $userpath = "C:\FTP\LocalUser\$usuario"
                        $reprobadosPath = "C:\FTP\reprobados"
                        $recursadoresPath = "C:\FTP\recursadores"

                        if ($confirmacion -eq "S" -or $confirmacion -eq "s") {
                            # Cambiar el usuario de grupo
                            Remove-LocalGroupMember -Group $grupoAntiguo -Member $usuario -ErrorAction SilentlyContinue
                            Add-LocalGroupMember -Group $nuevoGrupo -Member $usuario -ErrorAction Stop

                            Remove-Item -Path "$userpath\$grupoAntiguo"

                            if ($nuevoGrupo -eq "reprobados") {
                                New-Item -ItemType Junction -Path "$userpath\$nuevoGrupo" -Target "$reprobadosPath"
                            } elseif ($nuevoGrupo -eq "recursadores") {
                                New-Item -ItemType Junction -Path "$userpath\$nuevoGrupo" -Target "$recursadoresPath"
                            } else {
                                Write-Host "Error: Grupo no reconocido '$nuevoGrupo'." -ForegroundColor Red
                            }

                            Write-Host "Usuario '$usuario' cambiado a '$nuevoGrupo' correctamente." -ForegroundColor Green
                        } else {
                            Write-Host "Cambio de grupo cancelado." -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host "Error al cambiar el usuario de grupo: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    do{
                        Write-Host "Desea cambiar a otro usuario de grupo?"
                        $ver= Read-Host "Si(S) o No(N): "
                        $ver=$ver.ToUpper()
                        if($ver -ne "S" -and $ver -ne "N"){
                            Write-Host "Favor de ingresar S o N" -ForegroundColor Red
                        }
                    }while($ver -ne "S" -and $ver -ne "N")
                }while($ver -eq "S")
                Restart-Service -Name FTPSVC
                Restart-Service W3SVC
                Restart-WebItem "IIS:\Sites\FTP" -Verbose
            }
            4 { 
                Write-Host "Saliendo..." -ForegroundColor Green
            }
            Default {
                Write-Host "Opción no válida, favor de ingresar un numero del 1 al 4." -ForegroundColor Red
            }
        }
    }While($opc -ne 4)
}