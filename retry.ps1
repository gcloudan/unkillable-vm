# professional_spammer.ps1 - Clean, Quiet, Effective.

$waitTime = 60      # Retry speed
$attempt = 1
$startTime = Get-Date

Clear-Host
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "   ORACLE CLOUD CAPACITY FORCE - MELBOURNE AD-1    " -ForegroundColor White
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Target:   1 OCPU (Entry Ticket)" -ForegroundColor Yellow
Write-Host "Status:   Running..." -ForegroundColor Green
Write-Host "Logs:     Only failures and successes will be shown" -ForegroundColor Gray
Write-Host "---------------------------------------------------" -ForegroundColor Cyan

while ($true) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    # Update the UI to show we are working
    Write-Host -NoNewline "[$timestamp] Attempt #$attempt : " -ForegroundColor Gray

    # Run Terraform SILENTLY with -no-color to fix the weird characters
    $output = terraform apply -auto-approve -no-color 2>&1 | Out-String

    # --- PARSE THE RESULTS ---
    
    # 1. SUCCESS
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS! SERVER CREATED!" -ForegroundColor Green -BackgroundColor Black
        Write-Host "`n---------------------------------------------------"
        Write-Host "Verify IP in Console. Do not close this window." -ForegroundColor Yellow
        [System.Console]::Beep(1000, 500); [System.Console]::Beep(2000, 500)
        break
    }

    # 2. FAILURE (extract the specific reason)
    $cleanError = "Unknown Error"
    $reqId = "Unknown"

    # Find the specific "Out of capacity" line
    if ($output -match "(500-InternalError.*)") {
        $cleanError = $matches[1].Trim()
    } elseif ($output -match "Error: (.*)") {
        $cleanError = $matches[1].Trim()
    }

    # Find the Request ID (The Receipt)
    if ($output -match "OPC request ID: ([a-f0-9\/]+)") {
        $reqId = $matches[1]
    }

    # --- PRINT THE CLEAN STATUS ---
    if ($cleanError -match "Out of host capacity") {
        Write-Host "FULL (Capacity Reached)" -ForegroundColor DarkGray -NoNewline
        Write-Host " [ID: $reqId]" -ForegroundColor DarkMagenta
    } elseif ($cleanError -match "404") {
        Write-Host "CRITICAL ERROR: $cleanError" -ForegroundColor Red
        break
    } else {
        Write-Host "ERROR: $cleanError" -ForegroundColor Red
    }

    $attempt++
    Start-Sleep -Seconds $waitTime
}
