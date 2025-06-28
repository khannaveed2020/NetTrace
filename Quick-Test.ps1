# Quick Test Script for NetTrace Module
# Run this in PowerShell as Administrator

Write-Host "=== NetTrace Module Quick Test ===" -ForegroundColor Cyan
Write-Host ""

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
    Write-Host "✅ Module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "FAILED to import module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create test directory
$testPath = "C:\Traces"
if (!(Test-Path $testPath)) {
    New-Item -Path $testPath -ItemType Directory -Force | Out-Null
    Write-Host "✅ Created test directory: $testPath" -ForegroundColor Green
} else {
    Write-Host "✅ Test directory exists: $testPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Testing Non-Blocking Behavior ===" -ForegroundColor Cyan

# Test 1: Start trace (should return immediately)
Write-Host "Starting NetTrace..." -ForegroundColor Yellow
$startTime = Get-Date
NetTrace -File 2 -FileSize 10 -Path $testPath
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

if ($duration -lt 2) {
    Write-Host "✅ Command returned quickly ($([math]::Round($duration, 2)) seconds) - Non-blocking!" -ForegroundColor Green
} else {
    Write-Host "❌ Command took too long ($([math]::Round($duration, 2)) seconds) - May be blocking!" -ForegroundColor Red
}

# Test 2: Verify console is responsive
Write-Host ""
Write-Host "Testing console responsiveness..." -ForegroundColor Yellow
$testStart = Get-Date
Get-Date | Out-Null
Get-Process | Select-Object -First 1 | Out-Null
$testEnd = Get-Date
$testDuration = ($testEnd - $testStart).TotalMilliseconds

if ($testDuration -lt 1000) {
    Write-Host "✅ Console is responsive ($([math]::Round($testDuration)) ms)" -ForegroundColor Green
} else {
    Write-Host "❌ Console seems slow ($([math]::Round($testDuration)) ms)" -ForegroundColor Red
}

# Test 3: Check log file creation
Write-Host ""
Write-Host "Checking log file creation..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$logFiles = Get-ChildItem "$testPath\NetTrace_*.log" -ErrorAction SilentlyContinue

if ($logFiles) {
    Write-Host "✅ Log file created: $($logFiles[0].Name)" -ForegroundColor Green
    
    # Show first few lines of log
    Write-Host ""
    Write-Host "Log file content preview:" -ForegroundColor Cyan
    Get-Content $logFiles[0].FullName | Select-Object -First 8 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ No log file found" -ForegroundColor Red
}

# Test 4: Check ETL file creation
Write-Host ""
Write-Host "Checking ETL file creation..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$etlFiles = Get-ChildItem "$testPath\*.etl" -ErrorAction SilentlyContinue

if ($etlFiles) {
    Write-Host "✅ ETL file(s) created:" -ForegroundColor Green
    $etlFiles | ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  $($_.Name) ($sizeMB MB)" -ForegroundColor Gray
    }
} else {
    Write-Host "WARNING: No ETL files found yet (may take a moment)" -ForegroundColor Yellow
}

# Test 5: Stop functionality
Write-Host ""
Write-Host "Testing stop functionality..." -ForegroundColor Yellow
$stopStart = Get-Date
NetTrace -Stop
$stopEnd = Get-Date
$stopDuration = ($stopEnd - $stopStart).TotalSeconds

if ($stopDuration -lt 5) {
    Write-Host "✅ Stop command worked quickly ($([math]::Round($stopDuration, 2)) seconds)" -ForegroundColor Green
} else {
    Write-Host "❌ Stop command took too long ($([math]::Round($stopDuration, 2)) seconds)" -ForegroundColor Red
}

# Final results
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Check the following in ${testPath}:" -ForegroundColor Yellow
Write-Host "- NetTrace_*.log files (activity logs)" -ForegroundColor White
Write-Host "- *.etl files (network trace files)" -ForegroundColor White

Write-Host ""
Write-Host "=== Manual Verification ===" -ForegroundColor Cyan
Write-Host "To verify the fix worked:" -ForegroundColor Yellow
Write-Host "1. Console should have returned immediately" -ForegroundColor White
Write-Host "2. No excessive netsh output in console" -ForegroundColor White
Write-Host "3. Log file should contain detailed activity" -ForegroundColor White
Write-Host "4. NetTrace -Stop should work without CTRL+C" -ForegroundColor White

Write-Host ""
Write-Host "Test completed!" -ForegroundColor Green 