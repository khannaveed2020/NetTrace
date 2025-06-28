# Generate-NetworkTraffic.ps1
# This script generates network traffic to help test the NetTrace module
# Run this in a separate PowerShell window while NetTrace is running

param(
    [int]$DurationSeconds = 30,
    [int]$RequestsPerSecond = 5
)

Write-Host "Network Traffic Generator" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow
Write-Host "Duration: $DurationSeconds seconds" -ForegroundColor Cyan
Write-Host "Requests per second: $RequestsPerSecond" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will generate HTTP requests to help create network trace data." -ForegroundColor Green
Write-Host "Run this WHILE NetTrace is running in another window." -ForegroundColor Green
Write-Host ""

$urls = @(
    "https://www.google.com",
    "https://www.microsoft.com", 
    "https://www.github.com",
    "https://www.stackoverflow.com",
    "https://www.reddit.com"
)

$endTime = (Get-Date).AddSeconds($DurationSeconds)
$requestCount = 0

Write-Host "Starting traffic generation..." -ForegroundColor Green

try {
    while ((Get-Date) -lt $endTime) {
        $startTime = Get-Date
        
        # Make multiple requests in parallel
        for ($i = 0; $i -lt $RequestsPerSecond; $i++) {
            $url = $urls[$i % $urls.Count]
            
            # Use background jobs for parallel requests
            Start-Job -ScriptBlock {
                param($url)
                try {
                    Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing | Out-Null
                } catch {
                    # Ignore errors - we just want to generate traffic
                }
            } -ArgumentList $url | Out-Null
            
            $requestCount++
        }
        
        # Clean up completed jobs
        Get-Job | Where-Object { $_.State -eq 'Completed' } | Remove-Job
        
        Write-Host "Generated $requestCount requests..." -ForegroundColor Gray
        
        # Wait for the rest of the second
        $elapsed = (Get-Date) - $startTime
        $sleepTime = 1000 - $elapsed.TotalMilliseconds
        if ($sleepTime -gt 0) {
            Start-Sleep -Milliseconds $sleepTime
        }
    }
    
    # Clean up any remaining jobs
    Get-Job | Remove-Job -Force
    
    Write-Host ""
    Write-Host "Traffic generation completed!" -ForegroundColor Green
    Write-Host "Total requests sent: $requestCount" -ForegroundColor Cyan
    Write-Host "This should have generated enough network activity for your trace files." -ForegroundColor Green
    
} catch {
    Write-Host "Error generating traffic: $($_.Exception.Message)" -ForegroundColor Red
    Get-Job | Remove-Job -Force
} 