# Test-CircularBehavior.ps1
# Test script to demonstrate circular file management behavior

Write-Host "NetTrace Circular File Management Test" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Yellow
Write-Host ""

Write-Host "This test demonstrates the circular file management behavior:" -ForegroundColor Cyan
Write-Host "1. Creates File #1 (10MB) → Creates File #2 (10MB)" -ForegroundColor White
Write-Host "2. When File #2 reaches 10MB, creates File #3 and DELETES File #1" -ForegroundColor White
Write-Host "3. When File #3 reaches 10MB, creates File #4 and DELETES File #2" -ForegroundColor White
Write-Host "4. Continues this pattern, always keeping only 2 most recent files" -ForegroundColor White
Write-Host "5. Runs until manually stopped with NetTrace -Stop" -ForegroundColor White
Write-Host ""

Write-Host "Expected File Lifecycle:" -ForegroundColor Green
Write-Host "Files 1-2: [File1.etl, File2.etl]" -ForegroundColor Gray
Write-Host "File 3:    [File2.etl, File3.etl] ← File1 deleted" -ForegroundColor Gray
Write-Host "File 4:    [File3.etl, File4.etl] ← File2 deleted" -ForegroundColor Gray
Write-Host "File 5:    [File4.etl, File5.etl] ← File3 deleted" -ForegroundColor Gray
Write-Host "And so on..." -ForegroundColor Gray
Write-Host ""

$testPath = "C:\Temp\CircularTest"

# Check admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This test requires Administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator to test the circular behavior." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Running as Administrator" -ForegroundColor Green
Write-Host ""

# Import module
try {
    Import-Module .\NetTrace.psd1 -Force
    Write-Host "✓ NetTrace module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import NetTrace module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Test Command:" -ForegroundColor Cyan
Write-Host "NetTrace -File 2 -FileSize 10 -Path '$testPath' -Verbose" -ForegroundColor White
Write-Host ""

$runTest = Read-Host "Start circular file management test? (y/N)"

if ($runTest -eq 'y' -or $runTest -eq 'Y') {
    Write-Host ""
    Write-Host "Starting test..." -ForegroundColor Green
    Write-Host "Watch for 'Removed oldest file' messages when circular management begins!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To stop the test, open another Administrator PowerShell window and run:" -ForegroundColor Cyan
    Write-Host "NetTrace -Stop" -ForegroundColor White
    Write-Host ""
    
    # Create test directory
    if (Test-Path $testPath) {
        Remove-Item $testPath -Recurse -Force
    }
    New-Item -Path $testPath -ItemType Directory -Force | Out-Null
    
    # Start the test
    NetTrace -File 2 -FileSize 10 -Path $testPath -Verbose
    
} else {
    Write-Host "Test cancelled." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test completed or cancelled." -ForegroundColor Green 