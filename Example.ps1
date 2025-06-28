#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Example script demonstrating NetTrace module usage
    
.DESCRIPTION
    This script shows how to use the NetTrace module with the new simplified interface.
    It creates network traces with automatic file rotation based on size limits.
#>

# Import the NetTrace module
Import-Module .\NetTrace.psd1 -Force

Write-Host "NetTrace Module Example" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host ""

# Example 1: Basic usage without verbose output
Write-Host "Example 1: Basic trace (3 files, 50MB each)" -ForegroundColor Yellow
Write-Host "Command: NetTrace -File 3 -FileSize 50 -Path 'C:\Temp\NetTraces'" -ForegroundColor Gray
Write-Host ""

# Uncomment the line below to run the example
# NetTrace -File 3 -FileSize 50 -Path "C:\Temp\NetTraces"

Write-Host ""
Write-Host "Example 2: Verbose trace (5 files, 100MB each)" -ForegroundColor Yellow
Write-Host "Command: NetTrace -File 5 -FileSize 100 -Path 'C:\Temp\NetTraces' -Verbose" -ForegroundColor Gray
Write-Host ""

# Uncomment the line below to run the verbose example
# NetTrace -File 5 -FileSize 100 -Path "C:\Temp\NetTraces" -Verbose

Write-Host ""
Write-Host "Example 3: Stop current trace" -ForegroundColor Yellow
Write-Host "Command: NetTrace -Stop" -ForegroundColor Gray
Write-Host ""

# Uncomment the line below to stop any running trace
# NetTrace -Stop

Write-Host ""
Write-Host "Output Behavior:" -ForegroundColor Cyan
Write-Host "- Without -Verbose: Shows only filenames created and final summary" -ForegroundColor White
Write-Host "- With -Verbose: Shows detailed progress, file sizes, and rotation info" -ForegroundColor White
Write-Host ""
Write-Host "File Format: <computername>_dd-MM-yy-HHmmss.etl" -ForegroundColor Cyan
Write-Host "Example: MYPC_25-12-24-143022.etl" -ForegroundColor White
Write-Host ""
Write-Host "Features:" -ForegroundColor Cyan
Write-Host "- Report generation is disabled" -ForegroundColor White
Write-Host "- No additional data capture beyond network traces" -ForegroundColor White
Write-Host "- Automatic file rotation when size limit is reached" -ForegroundColor White
Write-Host "- Creates exactly the specified number of files" -ForegroundColor White 