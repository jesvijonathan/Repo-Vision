$connections = Get-NetTCPConnection -LocalPort 8080
if ($connections -and $connections.Count -gt 0) {
	Write-Host "Stopping existing server on port 8080"
    $connections | ForEach-Object { Stop-Process -Id (Get-Process -Id $_.OwningProcess).Id -Force }
}

./bin/llama/llama-server.exe -m ./models/$env:model -c 15000 -ngl 999