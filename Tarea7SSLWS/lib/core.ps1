function Write-Log {
    param($msg)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $msg" | Out-File -Append $LOG_FILE
}

function Die {
    param($msg)
    Write-Host "ERROR: $msg" -ForegroundColor Red
    Write-Log $msg
    exit
}