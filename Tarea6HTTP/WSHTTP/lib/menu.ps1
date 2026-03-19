function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host "===== HTTP Windows ====="
        Write-Host "1) IIS"
        Write-Host "2) Apache"
        Write-Host "3) Nginx"
        Write-Host "4) Salir"

        $op = Read-Number "Selecciona opción"

        switch ($op) {
            1 { Install-IIS }
            2 { Install-Apache }
            3 { Install-Nginx }
            4 { break }
        }

        Pause
    }
}