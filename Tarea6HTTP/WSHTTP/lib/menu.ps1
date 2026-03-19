function Show-UninstallMenu {
    while ($true) {
        Clear-Host
        Write-Host "===== DESINSTALAR SERVICIOS ====="
        Write-Host "1) Desinstalar IIS"
        Write-Host "2) Desinstalar Apache"
        Write-Host "3) Desinstalar Nginx"
        Write-Host "4) Volver"

        $op = Read-Number "Selecciona opción"

        switch ($op) {
            1 { Uninstall-IIS; Pause }
            2 { Uninstall-Apache; Pause }
            3 { Uninstall-Nginx; Pause }
            4 { return }
        }
    }
}

function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host "===== HTTP Windows ====="
        Write-Host "1) Instalar IIS"
        Write-Host "2) Instalar Apache"
        Write-Host "3) Instalar Nginx"
        Write-Host "4) Desinstalar servicios"
        Write-Host "5) Salir"

        $op = Read-Number "Selecciona opción"

        switch ($op) {
            1 { Install-IIS; Pause }
            2 { Install-Apache; Pause }
            3 { Install-Nginx; Pause }
            4 { Show-UninstallMenu }
            5 { break }
        }
    }
}