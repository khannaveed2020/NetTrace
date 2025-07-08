#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    NetTrace Service Runner and Management Script

.DESCRIPTION
    This script provides management functionality for the NetTrace Windows Service.
    It handles service installation, configuration, starting, stopping, and status monitoring.

.PARAMETER Install
    Installs the NetTrace Windows Service

.PARAMETER Uninstall
    Uninstalls the NetTrace Windows Service

.PARAMETER Start
    Starts the NetTrace Windows Service with specified parameters

.PARAMETER Stop
    Stops the NetTrace Windows Service

.PARAMETER Status
    Shows the current status of the NetTrace Windows Service

.PARAMETER Path
    Directory path where trace files will be stored (required for Start)

.PARAMETER MaxFiles
    Maximum number of trace files to maintain (required for Start)

.PARAMETER MaxSizeMB
    Maximum size of each trace file in MB (required for Start)

.PARAMETER LogOutput
    Enable netsh output logging (optional)

.PARAMETER EnableLogging
    Enable detailed activity logging (optional)

.NOTES
    File Name      : NetTrace-ServiceRunner.ps1
    Version        : 1.2.1
    Author         : Naveed Khan
    Company        : Hogwarts
    Copyright      : (c) 2025 Naveed Khan. All rights reserved.
    License        : MIT License
    Prerequisite   : Windows 10/11 with Administrator privileges
    Requires       : PowerShell 5.1 or PowerShell 7+

.EXAMPLE
    .\NetTrace-ServiceRunner.ps1 -Install
    Installs the NetTrace Windows Service

.EXAMPLE
    .\NetTrace-ServiceRunner.ps1 -Start -Path "C:\Traces" -MaxFiles 3 -MaxSizeMB 10 -EnableLogging
    Starts the service with specified parameters and logging enabled

.EXAMPLE
    .\NetTrace-ServiceRunner.ps1 -Stop
    Stops the NetTrace Windows Service

.EXAMPLE
    .\NetTrace-ServiceRunner.ps1 -Status
    Shows current service status

.EXAMPLE
    .\NetTrace-ServiceRunner.ps1 -Uninstall
    Uninstalls the NetTrace Windows Service

.LINK
    https://github.com/khannaveed2020/NetTrace
#>

[CmdletBinding(DefaultParameterSetName = 'Status')]
param(
    [Parameter(ParameterSetName = 'Install', Mandatory = $true)]
    [switch]$Install,
    
    [Parameter(ParameterSetName = 'Uninstall', Mandatory = $true)]
    [switch]$Uninstall,
    
    [Parameter(ParameterSetName = 'Start', Mandatory = $true)]
    [switch]$Start,
    
    [Parameter(ParameterSetName = 'Stop', Mandatory = $true)]
    [switch]$Stop,
    
    [Parameter(ParameterSetName = 'Status', Mandatory = $false)]
    [switch]$Status,
    
    [Parameter(ParameterSetName = 'Start', Mandatory = $true)]
    [string]$Path,
    
    [Parameter(ParameterSetName = 'Start', Mandatory = $true)]
    [int]$MaxFiles,
    
    [Parameter(ParameterSetName = 'Start', Mandatory = $true)]
    [int]$MaxSizeMB,
    
    [Parameter(ParameterSetName = 'Start', Mandatory = $false)]
    [switch]$LogOutput,
    
    [Parameter(ParameterSetName = 'Start', Mandatory = $false)]
    [switch]$EnableLogging
)

# Service configuration
$ServiceName = "NetTraceService"
$ServiceDisplayName = "NetTrace Network Monitoring Service"
$ServiceDescription = "Provides persistent network trace monitoring with automatic file rotation and circular management"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServiceScript = Join-Path $ScriptDir "NetTrace-Service.ps1"

# Check if service script exists
if (!(Test-Path $ServiceScript)) {
    Write-Error "NetTrace-Service.ps1 not found in script directory: $ScriptDir"
    exit 1
}

# Import service functions
. $ServiceScript

function Install-NetTraceService {
    Write-Host "Installing NetTrace Windows Service..." -ForegroundColor Green
    
    try {
        # Create service using New-Service
        $serviceParams = @{
            Name = $ServiceName
            DisplayName = $ServiceDisplayName
            Description = $ServiceDescription
            BinaryPathName = "powershell.exe -ExecutionPolicy Bypass -File `"$ServiceScript`""
            StartupType = "Manual"
        }
        
        $service = New-Service @serviceParams -ErrorAction Stop
        
        if ($service) {
            Write-Host "✓ NetTrace Windows Service installed successfully" -ForegroundColor Green
            Write-Host "  Service Name: $ServiceName" -ForegroundColor Gray
            Write-Host "  Display Name: $ServiceDisplayName" -ForegroundColor Gray
            Write-Host "  Startup Type: Manual" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Use 'NetTrace-ServiceRunner.ps1 -Start' to start the service with parameters" -ForegroundColor Yellow
            return $true
        }
    } catch {
        Write-Error "Failed to install NetTrace Windows Service: $($_.Exception.Message)"
        return $false
    }
}

function Uninstall-NetTraceService {
    Write-Host "Uninstalling NetTrace Windows Service..." -ForegroundColor Yellow
    
    try {
        # Stop service if running
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-Host "Stopping service..." -ForegroundColor Gray
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }
        
        # Remove service
        if ($service) {
            Remove-Service -Name $ServiceName -ErrorAction Stop
            Write-Host "✓ NetTrace Windows Service uninstalled successfully" -ForegroundColor Green
        } else {
            Write-Host "NetTrace Windows Service is not installed" -ForegroundColor Gray
        }
        
        # Clean up service state directory
        $ServiceStateDir = "$env:ProgramData\NetTrace"
        if (Test-Path $ServiceStateDir) {
            Write-Host "Cleaning up service state directory..." -ForegroundColor Gray
            Remove-Item $ServiceStateDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        return $true
    } catch {
        Write-Error "Failed to uninstall NetTrace Windows Service: $($_.Exception.Message)"
        return $false
    }
}

function Start-NetTraceServiceRunner {
    param(
        [string]$TracePath,
        [int]$MaxFiles,
        [int]$MaxSizeMB,
        [bool]$LogOutput,
        [bool]$EnableLogging
    )
    
    Write-Host "Starting NetTrace Windows Service..." -ForegroundColor Green
    
    try {
        # Validate parameters
        if ($MaxFiles -le 0) {
            throw "MaxFiles parameter must be a positive integer"
        }
        if ($MaxSizeMB -le 0) {
            throw "MaxSizeMB parameter must be a positive integer"
        }
        if ($MaxSizeMB -lt 10) {
            throw "MaxSizeMB must be at least 10 MB. Netsh trace has a minimum file size of 10MB."
        }
        if ([string]::IsNullOrWhiteSpace($TracePath)) {
            throw "Path parameter is required"
        }
        
        # Ensure directory exists
        if (!(Test-Path $TracePath)) {
            New-Item -Path $TracePath -ItemType Directory -Force | Out-Null
            Write-Host "Created directory: $TracePath" -ForegroundColor Gray
        }
        
        # Check if service is already running
        $currentStatus = Get-ServiceStatus
        if ($currentStatus.IsRunning) {
            Write-Warning "NetTrace service is already running. Use -Stop first to stop the current session."
            return $false
        }
        
        # Start the service
        $success = Start-NetTraceService -Path $TracePath -MaxFiles $MaxFiles -MaxSizeMB $MaxSizeMB -LogOutput $LogOutput -EnableLogging $EnableLogging
        
        if ($success) {
            Write-Host "✓ NetTrace Windows Service started successfully" -ForegroundColor Green
            Write-Host "  Path: $TracePath" -ForegroundColor Gray
            Write-Host "  Max Files: $MaxFiles" -ForegroundColor Gray
            Write-Host "  Max Size: $MaxSizeMB MB" -ForegroundColor Gray
            Write-Host "  Logging: $(if ($EnableLogging) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
            Write-Host "  NetSH Output: $(if ($LogOutput) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Service is now running in the background with true persistence." -ForegroundColor Green
            Write-Host "Use 'NetTrace -Stop' or 'NetTrace-ServiceRunner.ps1 -Stop' to stop the service." -ForegroundColor Yellow
            
            if ($EnableLogging) {
                Write-Host "Monitor progress with: Get-Content '$TracePath\NetTrace_*.log' -Wait" -ForegroundColor Yellow
            }
            
            return $true
        } else {
            Write-Error "Failed to start NetTrace Windows Service"
            return $false
        }
    } catch {
        Write-Error "Error starting NetTrace Windows Service: $($_.Exception.Message)"
        return $false
    }
}

function Stop-NetTraceServiceRunner {
    Write-Host "Stopping NetTrace Windows Service..." -ForegroundColor Yellow
    
    try {
        $success = Stop-NetTraceService
        
        if ($success) {
            Write-Host "✓ NetTrace Windows Service stopped successfully" -ForegroundColor Green
            
            # Show final status
            $finalStatus = Get-ServiceStatus
            Write-Host "Final Status:" -ForegroundColor Gray
            Write-Host "  Files Created: $($finalStatus.FilesCreated)" -ForegroundColor Gray
            Write-Host "  Files Rolled: $($finalStatus.FilesRolled)" -ForegroundColor Gray
            
            return $true
        } else {
            Write-Error "Failed to stop NetTrace Windows Service"
            return $false
        }
    } catch {
        Write-Error "Error stopping NetTrace Windows Service: $($_.Exception.Message)"
        return $false
    }
}

function Show-NetTraceServiceStatus {
    Write-Host "NetTrace Windows Service Status" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    try {
        # Check Windows Service status
        $windowsService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($windowsService) {
            Write-Host "Windows Service: $($windowsService.Status)" -ForegroundColor $(if ($windowsService.Status -eq 'Running') { 'Green' } else { 'Gray' })
        } else {
            Write-Host "Windows Service: Not Installed" -ForegroundColor Red
        }
        
        # Check NetTrace service status
        $netTraceStatus = Get-ServiceStatus
        Write-Host "NetTrace Service: $(if ($netTraceStatus.IsRunning) { 'Running' } else { 'Stopped' })" -ForegroundColor $(if ($netTraceStatus.IsRunning) { 'Green' } else { 'Gray' })
        
        if ($netTraceStatus.IsRunning) {
            Write-Host ""
            Write-Host "Service Details:" -ForegroundColor Gray
            Write-Host "  Files Created: $($netTraceStatus.FilesCreated)" -ForegroundColor Gray
            Write-Host "  Files Rolled: $($netTraceStatus.FilesRolled)" -ForegroundColor Gray
            Write-Host "  Current File: $($netTraceStatus.CurrentFile)" -ForegroundColor Gray
            Write-Host "  Last Update: $($netTraceStatus.LastUpdate)" -ForegroundColor Gray
            
            if ($netTraceStatus.ErrorMessage) {
                Write-Host "  Error: $($netTraceStatus.ErrorMessage)" -ForegroundColor Red
            }
            
            # Show configuration
            $config = Get-ServiceConfig
            if ($config) {
                Write-Host ""
                Write-Host "Configuration:" -ForegroundColor Gray
                Write-Host "  Path: $($config.Path)" -ForegroundColor Gray
                Write-Host "  Max Files: $($config.MaxFiles)" -ForegroundColor Gray
                Write-Host "  Max Size: $($config.MaxSizeMB) MB" -ForegroundColor Gray
                Write-Host "  Logging: $(if ($config.EnableLogging) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
                Write-Host "  NetSH Output: $(if ($config.LogOutput) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
                Write-Host "  Started: $($config.StartTime)" -ForegroundColor Gray
            }
        } else {
            if ($netTraceStatus.ErrorMessage) {
                Write-Host "Last Error: $($netTraceStatus.ErrorMessage)" -ForegroundColor Red
            }
        }
        
        return $true
    } catch {
        Write-Error "Error retrieving NetTrace Windows Service status: $($_.Exception.Message)"
        return $false
    }
}

# Main execution logic
try {
    Write-Host "NetTrace Service Runner v1.2.1" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
    
    switch ($PSCmdlet.ParameterSetName) {
        'Install' {
            Install-NetTraceService
        }
        'Uninstall' {
            Uninstall-NetTraceService
        }
        'Start' {
            Start-NetTraceServiceRunner -TracePath $Path -MaxFiles $MaxFiles -MaxSizeMB $MaxSizeMB -LogOutput:$LogOutput -EnableLogging:$EnableLogging
        }
        'Stop' {
            Stop-NetTraceServiceRunner
        }
        'Status' {
            Show-NetTraceServiceStatus
        }
    }
} catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
    exit 1
} 