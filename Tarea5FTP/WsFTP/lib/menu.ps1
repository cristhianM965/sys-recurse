function Mostrar-MenuPrincipal {
    do {
        Clear-Host
        Write-Host "=====================================" -ForegroundColor Cyan
        Write-Host "   AUTOMATIZACION FTP WINDOWS IIS" -ForegroundColor Cyan
        Write-Host "=====================================" -ForegroundColor Cyan
        Write-Host "1. Instalar y configurar FTP"
        Write-Host "2. Crear grupos requeridos"
        Write-Host "3. Crear usuarios FTP"
        Write-Host "4. Cambiar grupo de un usuario"
        Write-Host "5. Eliminar usuario"
        Write-Host "6. Listar usuarios"
        Write-Host "7. Salir"
        Write-Host "====================================="

        $opcion = Read-Host "Seleccione una opción"

        switch ($opcion) {
            "1" {
                Asegurar-Grupos
                Configurar-FTPCompleto
                Pause
            }
            "2" {
                Asegurar-Grupos
                Pause
            }
            "3" {
                Asegurar-Grupos
                Crear-UsuariosInteractivo
                Pause
            }
            "4" {
                Cambiar-GrupoUsuario
                Pause
            }
            "5" {
                Eliminar-UsuarioFTP
                Pause
            }
            "6" {
                Listar-UsuariosFTP
                Pause
            }
            "7" {
                Write-Host "Saliendo..." -ForegroundColor Yellow
            }
            default {
                Write-Host "Opción inválida." -ForegroundColor Red
                Pause
            }
        }
    } while ($opcion -ne "7")
}