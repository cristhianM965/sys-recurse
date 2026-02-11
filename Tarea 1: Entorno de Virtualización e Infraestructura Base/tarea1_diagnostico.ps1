Write-Host "====================================="
Write-Host "  DIAGNOSTICO INICIAL DEL SISTEMA"
Write-Host "====================================="

Write-Host "Nombre del equipo:"
Write-Host $env:COMPUTERNAME
Write-Host ""

Write-Host "Direccion IP (IPv4 activas):"
Get-NetIPAddress -AddressFamily IPv4 |
Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
Select-Object InterfaceAlias, IPAddress |
Format-Table -AutoSize

Write-Host ""
Write-Host "Espacio en disco:"
Get-PSDrive -PSProvider FileSystem |
Select-Object Name, Used, Free |
Format-Table -AutoSize

Write-Host "====================================="
