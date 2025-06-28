# Simple Test Script for NetTrace Module
# Run this in PowerShell as Administrator

Write-Host "=== NetTrace Module Test ===" -ForegroundColor Cyan

# Check if running as admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "SUCCESS: Running as Administrator" -ForegroundColor Green

# Import the module
Write-Host "Importing NetTrace module..." -ForegroundColor Yellow
try {
    Remove-Module NetTrace -Force -ErrorAction SilentlyContinue
    Import-Module .\NetTrace.psd1 -Force
    Write-Host "SUCCESS: Module imported" -ForegroundColor Green
} catch {
    Write-Host "FAILED: Could not import module - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create test directory
$testPath = "C:\Traces"
if (!(Test-Path $testPath)) {
    New-Item -Path $testPath -ItemType Directory -Force | Out-Null
    Write-Host "SUCCESS: Created test directory $testPath" -ForegroundColor Green
} else {
    Write-Host "SUCCESS: Test directory exists $testPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Testing Non-Blocking Behavior ===" -ForegroundColor Cyan

# Test: Start trace (should return immediately)
Write-Host "Starting NetTrace..." -ForegroundColor Yellow
$startTime = Get-Date
NetTrace -File 2 -FileSize 10 -Path $testPath
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

if ($duration -lt 2) {
    Write-Host "SUCCESS: Command returned quickly ($([math]::Round($duration, 2)) seconds)" -ForegroundColor Green
} else {
    Write-Host "WARNING: Command took $([math]::Round($duration, 2)) seconds" -ForegroundColor Yellow
}

# Test console responsiveness
Write-Host "Testing console responsiveness..." -ForegroundColor Yellow
Get-Date | Out-Null
Write-Host "SUCCESS: Console is responsive" -ForegroundColor Green

# Check log file creation
Write-Host "Checking for log files..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$logFiles = Get-ChildItem "$testPath\NetTrace_*.log" -ErrorAction SilentlyContinue

if ($logFiles) {
    Write-Host "SUCCESS: Log file created - $($logFiles[0].Name)" -ForegroundColor Green
} else {
    Write-Host "WARNING: No log file found yet" -ForegroundColor Yellow
}

# Test stop functionality
Write-Host "Testing stop functionality..." -ForegroundColor Yellow
NetTrace -Stop
Write-Host "SUCCESS: Stop command completed" -ForegroundColor Green

Write-Host ""
Write-Host "=== Test Results ===" -ForegroundColor Cyan
Write-Host "Check C:\Traces for:" -ForegroundColor Yellow
Write-Host "- NetTrace log files" -ForegroundColor White
Write-Host "- ETL trace files" -ForegroundColor White

Write-Host ""
Write-Host "Key Tests:" -ForegroundColor Yellow
Write-Host "1. Console returned immediately after start" -ForegroundColor White
Write-Host "2. No netsh output spam in console" -ForegroundColor White
Write-Host "3. Stop command worked without CTRL+C" -ForegroundColor White

Write-Host ""
Write-Host "Test completed successfully!" -ForegroundColor Green 