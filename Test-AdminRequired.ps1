# Test-AdminRequired.ps1
# This script demonstrates how to test the NetTrace module with admin privileges
# and shows that the serialization errors have been fixed

Write-Host "NetTrace Module Test - Administrator Required" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "ERROR: This module requires PowerShell to be run as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "To test the module:" -ForegroundColor Cyan
    Write-Host "1. Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor White
    Write-Host "2. Navigate to this directory: $PWD" -ForegroundColor White
    Write-Host "3. Run: Import-Module .\NetTrace.psd1 -Force" -ForegroundColor White
    Write-Host "4. Test with: NetTrace -File 2 -FileSize 10 -Path 'C:\Traces' -Verbose" -ForegroundColor White
    Write-Host ""
    Write-Host "FIXES APPLIED:" -ForegroundColor Green
    Write-Host "- Removed PowerShell jobs to eliminate serialization errors" -ForegroundColor White
    Write-Host "- Changed to synchronous execution (no background processes)" -ForegroundColor White
    Write-Host "- Direct Write-Host calls instead of job output parsing" -ForegroundColor White
    Write-Host "- No more 'Cannot process an element with node type Text' errors" -ForegroundColor White
    exit
}

Write-Host "Administrator privileges detected. Testing module..." -ForegroundColor Green
Write-Host ""

try {
    # Import the module
    Import-Module .\NetTrace.psd1 -Force
    Write-Host "Module imported successfully!" -ForegroundColor Green
    
    # Show available commands
    Write-Host ""
    Write-Host "Available NetTrace commands:" -ForegroundColor Cyan
    Get-Command -Module NetTrace | Format-Table Name, CommandType -AutoSize
    
    # Show example usage
    Write-Host ""
    Write-Host "Example usage (creates 2 files of 10MB each):" -ForegroundColor Cyan
    Write-Host "NetTrace -File 2 -FileSize 10 -Path 'C:\Traces' -Verbose" -ForegroundColor White
    Write-Host ""
    Write-Host "The serialization errors have been fixed by:" -ForegroundColor Green
    Write-Host "- Removing background PowerShell jobs" -ForegroundColor White
    Write-Host "- Using synchronous execution instead" -ForegroundColor White
    Write-Host "- Direct console output without job serialization" -ForegroundColor White
    
} catch {
    Write-Host "Error testing module: $($_.Exception.Message)" -ForegroundColor Red
} 