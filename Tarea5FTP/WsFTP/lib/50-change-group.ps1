function Change-FTPUserGroup {
  Core-Banner "6) Cambiar grupo de un usuario"

  $u = Read-Host "Usuario"
  if(-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)){
    throw "No existe usuario: $u"
  }

  Write-Host "Nuevo grupo: 1) $($Global:GROUP_A)  2) $($Global:GROUP_B)"
  $opt = Read-Host "Elige (1/2)"
  $newg = if($opt -eq "1"){ $Global:GROUP_A } elseif($opt -eq "2"){ $Global:GROUP_B } else { throw "Opción inválida" }

  # Actualiza membership
  Add-ToGroup $newg $u
  if($newg -eq $Global:GROUP_A){ Remove-FromGroup $Global:GROUP_B $u } else { Remove-FromGroup $Global:GROUP_A $u }

  # Actualiza junctions (borra los dos nombres posibles y crea el correcto)
  $uRoot = Join-Path $Global:T5_LOCALUSER $u
  $oldA = Join-Path $uRoot $Global:GROUP_A
  $oldB = Join-Path $uRoot $Global:GROUP_B

  if(Test-Path $oldA){ cmd /c "rmdir `"$oldA`"" | Out-Null }
  if(Test-Path $oldB){ cmd /c "rmdir `"$oldB`"" | Out-Null }

  Ensure-Junction (Join-Path $uRoot $newg) (Join-Path $Global:T5_GROUPS $newg)

  Core-Log "Grupo cambiado: $u -> $newg"
}