#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    NetTrace Service Runner and Management Script

.DESCRIPTION
    This script provides management functionality for the NetTrace Windows Service using NSSM (Non-Sucking Service Manager).
    It handles service installation, configuration, starting, stopping, and status monitoring for true Windows Service persistence.
    
    Version 1.3.6 includes comprehensive documentation enhancements:
    - Fixed NSSM installation to use persistent location instead of temp directory
    - Simplified service configuration using batch file wrapper
    - Enhanced service validation and error handling
    - Improved parameter passing to avoid complex escaping issues

.PARAMETER Install
    Installs the NetTrace Windows Service using NSSM

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
    Version        : 1.3.6
    Author         : Naveed Khan
    Company        : Hogwarts
    Copyright      : (c) 2025 Naveed Khan. All rights reserved.
    License        : MIT License
    Prerequisite   : Windows 10/11 with Administrator privileges
    Requires       : PowerShell 5.1 or PowerShell 7+
    Dependencies   : NSSM (Non-Sucking Service Manager) - automatically downloaded

.EXAMPLE
    .\NetTrace-ServiceRunner.ps1 -Install
    Installs the NetTrace Windows Service using NSSM

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

# NSSM management functions - FIXED VERSION
function Get-NSSM {
    <#
    .SYNOPSIS
        Gets NSSM for service management with persistent storage
    .DESCRIPTION
        Checks if NSSM is available in system PATH first, then downloads to persistent location if needed
    #>

    # First check if NSSM is available in system PATH (user may have installed it)
    $systemNssm = Get-Command nssm -ErrorAction SilentlyContinue
    if ($systemNssm) {
        Write-Information "NSSM found in system PATH: $($systemNssm.Source)" -InformationAction Continue
        return $systemNssm.Source
    }

    # FIXED: Use persistent location instead of temp directory
    $nssmDir = "$env:ProgramData\NetTrace\NSSM"
    $nssmPath = "$nssmDir\nssm.exe"

    # Check if NSSM is already available in persistent location
    if (Test-Path $nssmPath) {
        Write-Information "NSSM found at: $nssmPath" -InformationAction Continue
        return $nssmPath
    }

    Write-Information "Downloading NSSM (Non-Sucking Service Manager) to persistent location..." -InformationAction Continue

    try {
        # Create directory if it doesn't exist
        if (!(Test-Path $nssmDir)) {
            New-Item -Path $nssmDir -ItemType Directory -Force | Out-Null
        }

        # Download NSSM
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        $nssmZip = "$nssmDir\nssm.zip"

        # Use System.Net.WebClient for reliable download
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($nssmUrl, $nssmZip)

        # Extract NSSM
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($nssmZip)

        # Find the correct nssm.exe for current architecture
        $architecture = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
        $nssmEntry = $zip.Entries | Where-Object { $_.FullName -like "*/$architecture/nssm.exe" }

        if ($nssmEntry) {
            $stream = $nssmEntry.Open()
            $fileStream = [System.IO.File]::Create($nssmPath)
            $stream.CopyTo($fileStream)
            $fileStream.Close()
            $stream.Close()
        } else {
            throw "Could not find nssm.exe for architecture: $architecture"
        }

        $zip.Dispose()

        # Clean up zip file
        Remove-Item $nssmZip -Force -ErrorAction SilentlyContinue

        if (Test-Path $nssmPath) {
            Write-Information "NSSM downloaded successfully to persistent location: $nssmPath" -InformationAction Continue
            return $nssmPath
        } else {
            throw "NSSM download failed - file not found after extraction"
        }

    } catch {
        Write-Error "Failed to download NSSM: $($_.Exception.Message)"
        Write-Information "Manual installation: Download NSSM from https://nssm.cc/ and place nssm.exe in $nssmDir" -InformationAction Continue
        return $null
    }
}

function New-ServiceWrapper {
    <#
    .SYNOPSIS
        Creates a batch file wrapper for the PowerShell service script
    .DESCRIPTION
        Creates a simple batch file to avoid complex PowerShell parameter escaping issues with NSSM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$ServiceScriptPath,
        [string]$WrapperPath
    )

    if ($PSCmdlet.ShouldProcess($WrapperPath, "Create service wrapper batch file")) {
        try {
            $batchContent = @"
@echo off
REM NetTrace Service Wrapper
REM This batch file starts the NetTrace PowerShell service script
REM Created automatically by NetTrace-ServiceRunner.ps1

REM Change to script directory to ensure proper module loading
cd /d "$ScriptDir"

REM Start PowerShell with the service script
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "$ServiceScriptPath" -ServiceMode

REM Exit with the same code as PowerShell
exit /b %ERRORLEVEL%
"@

            $batchContent | Out-File -FilePath $WrapperPath -Encoding ASCII -Force
            
            if (Test-Path $WrapperPath) {
                Write-Information "Service wrapper created: $WrapperPath" -InformationAction Continue
                return $true
            } else {
                throw "Failed to create wrapper file"
            }
        } catch {
            Write-Error "Failed to create service wrapper: $($_.Exception.Message)"
            return $false
        }
    }
    return $false
}

function Install-NetTraceWindowsService {
    <#
    .SYNOPSIS
        Installs NetTrace as a Windows Service using NSSM with simplified configuration
    .DESCRIPTION
        Uses NSSM to install NetTrace as a proper Windows Service with batch file wrapper for reliability
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Install")) {
        Write-Information "Installing NetTrace as Windows Service using NSSM..." -InformationAction Continue

        try {
            # Get NSSM
            $nssm = Get-NSSM
            if (-not $nssm) {
                throw "NSSM is required for service installation"
            }

            # Check if service already exists - force reconfiguration if it does
            $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($existingService) {
                Write-Information "Service '$ServiceName' already exists. Forcing reconfiguration with current module version..." -InformationAction Continue

                # Stop and remove the existing service to ensure clean reinstall
                if ($existingService.Status -eq 'Running') {
                    & $nssm stop $ServiceName 2>&1 | Out-Null
                    Start-Sleep -Seconds 2
                }

                # Remove the service completely
                & $nssm remove $ServiceName confirm 2>&1 | Out-Null
                Start-Sleep -Seconds 2

                # Clean up service state
                $ServiceStateDir = "$env:ProgramData\NetTrace"
                if (Test-Path $ServiceStateDir) {
                    Remove-Item $ServiceStateDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # FIXED: Create simplified batch file wrapper instead of complex parameter escaping
            $ServiceStateDir = "$env:ProgramData\NetTrace"
            if (!(Test-Path $ServiceStateDir)) {
                New-Item -Path $ServiceStateDir -ItemType Directory -Force | Out-Null
            }

            $wrapperBatch = "$ServiceStateDir\NetTrace-Service.bat"
            $serviceScriptPath = (Get-Item $ServiceScript).FullName
            
            Write-Information "Creating service wrapper batch file..." -InformationAction Continue
            $wrapperSuccess = New-ServiceWrapper -ServiceScriptPath $serviceScriptPath -WrapperPath $wrapperBatch
            if (-not $wrapperSuccess) {
                throw "Failed to create service wrapper"
            }

            # Install service with NSSM using the batch file wrapper
            Write-Information "Installing service with wrapper: $wrapperBatch" -InformationAction Continue

            $installResult = & $nssm install $ServiceName $wrapperBatch 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "NSSM install failed: $installResult"
            }

            # Configure basic service settings
            & $nssm set $ServiceName AppDirectory "$ScriptDir"
            & $nssm set $ServiceName DisplayName "$ServiceDisplayName"
            & $nssm set $ServiceName Description "$ServiceDescription"
            & $nssm set $ServiceName Start SERVICE_AUTO_START
            & $nssm set $ServiceName Type SERVICE_WIN32_OWN_PROCESS

            # Ensure the service runs as LocalSystem for persistence
            & $nssm set $ServiceName ObjectName "LocalSystem"
            Write-Information "Service will run as LocalSystem for persistence across logoff/reboot." -InformationAction Continue

            # Configure service recovery
            & $nssm set $ServiceName AppStopMethodSkip 0
            & $nssm set $ServiceName AppStopMethodConsole 1500
            & $nssm set $ServiceName AppStopMethodWindow 1500
            & $nssm set $ServiceName AppStopMethodThreads 1500

            # Set service to restart on failure
            & $nssm set $ServiceName AppExit Default Restart
            & $nssm set $ServiceName AppRestartDelay 60000

            # Configure logging
            $logDir = "$env:ProgramData\NetTrace\service_logs"
            if (!(Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }

            & $nssm set $ServiceName AppStdout "$logDir\service_stdout.log"
            & $nssm set $ServiceName AppStderr "$logDir\service_stderr.log"

            # ENHANCED: Validate service installation
            Write-Information "Validating service installation..." -InformationAction Continue
            $installedService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if (-not $installedService) {
                throw "Service installation validation failed - service not found"
            }

            # Validate wrapper file exists and is accessible
            if (-not (Test-Path $wrapperBatch)) {
                throw "Service wrapper validation failed - wrapper file not found"
            }

            # Validate service script exists and is accessible
            if (-not (Test-Path $serviceScriptPath)) {
                throw "Service script validation failed - script file not found"
            }

            Write-Information "NetTrace Windows Service installed successfully" -InformationAction Continue
            Write-Information "  Service Name: $ServiceName" -InformationAction Continue
            Write-Information "  Display Name: $ServiceDisplayName" -InformationAction Continue
            Write-Information "  Startup Type: Automatic" -InformationAction Continue
            Write-Information "  Service Type: Windows Service (NSSM)" -InformationAction Continue
            Write-Information "  Wrapper: $wrapperBatch" -InformationAction Continue
            Write-Information "  Script: $serviceScriptPath" -InformationAction Continue
            Write-Information "" -InformationAction Continue
            Write-Information "Service is ready to use. Use 'NetTrace-ServiceRunner.ps1 -Start' to start the service." -InformationAction Continue

            return $true

        } catch {
            Write-Error "Failed to install NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Uninstall-NetTraceWindowsService {
    <#
    .SYNOPSIS
        Uninstalls the NetTrace Windows Service
    .DESCRIPTION
        Removes the NetTrace Windows Service using NSSM and cleans up all related files
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Uninstall")) {
        Write-Information "Uninstalling NetTrace Windows Service..." -InformationAction Continue

        try {
            # Get NSSM
            $nssm = Get-NSSM
            if (-not $nssm) {
                Write-Warning "NSSM not available. Attempting standard service removal..."
            }

            # Stop service if running
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.Status -eq 'Running') {
                    Write-Information "Stopping service..." -InformationAction Continue
                    if ($nssm) {
                        & $nssm stop $ServiceName
                    } else {
                        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                    }
                    Start-Sleep -Seconds 3
                }

                # Remove service
                if ($nssm) {
                    $removeResult = & $nssm remove $ServiceName confirm 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Information "NetTrace Windows Service uninstalled successfully" -InformationAction Continue
                    } else {
                        throw "NSSM remove failed: $removeResult"
                    }
                } else {
                    # Fallback to standard removal
                    Remove-Service -Name $ServiceName -ErrorAction Stop
                    Write-Information "NetTrace Windows Service uninstalled successfully (standard removal)" -InformationAction Continue
                }
            } else {
                Write-Information "NetTrace Windows Service is not installed" -InformationAction Continue
            }

            # Clean up service state directory and wrapper
            $ServiceStateDir = "$env:ProgramData\NetTrace"
            if (Test-Path $ServiceStateDir) {
                Write-Information "Cleaning up service state directory..." -InformationAction Continue
                Remove-Item $ServiceStateDir -Recurse -Force -ErrorAction SilentlyContinue
            }

            return $true

        } catch {
            Write-Error "Failed to uninstall NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Start-WindowsService {
    <#
    .SYNOPSIS
        Starts the NetTrace Windows Service with enhanced monitoring
    .DESCRIPTION
        Starts the Windows Service using NSSM or standard service controls with detailed status monitoring
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Start")) {
        try {
            # Get NSSM
            $nssm = Get-NSSM

            # Check if service exists
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if (-not $service) {
                throw "NetTrace Windows Service is not installed. Use -Install first."
            }

            # ENHANCED: Pre-start validation
            Write-Information "Performing pre-start validation..." -InformationAction Continue
            
            # Check if wrapper file exists
            $wrapperBatch = "$env:ProgramData\NetTrace\NetTrace-Service.bat"
            if (-not (Test-Path $wrapperBatch)) {
                Write-Warning "Service wrapper not found at: $wrapperBatch"
                Write-Information "Attempting to recreate wrapper..." -InformationAction Continue
                $serviceScriptPath = (Get-Item $ServiceScript).FullName
                $wrapperSuccess = New-ServiceWrapper -ServiceScriptPath $serviceScriptPath -WrapperPath $wrapperBatch
                if (-not $wrapperSuccess) {
                    throw "Failed to recreate service wrapper"
                }
            }

            # Check if service script exists
            if (-not (Test-Path $ServiceScript)) {
                throw "Service script not found: $ServiceScript"
            }

            # ENHANCED: Robust service state management
            $currentStatus = & $nssm status $ServiceName 2>&1
            Write-Information "Current service status: $currentStatus" -InformationAction Continue

            if ($currentStatus -eq "SERVICE_RUNNING") {
                Write-Information "Service is already running successfully" -InformationAction Continue
                return $true
            } elseif ($currentStatus -eq "SERVICE_PAUSED") {
                Write-Information "Service is paused, stopping and restarting..." -InformationAction Continue
                & $nssm stop $ServiceName 2>&1 | Out-Null
                Start-Sleep -Seconds 2
            } elseif ($currentStatus -eq "SERVICE_STOPPED") {
                Write-Information "Service is stopped, ready to start..." -InformationAction Continue
            } else {
                Write-Warning "Service in unexpected state: $currentStatus. Attempting to stop first..."
                & $nssm stop $ServiceName 2>&1 | Out-Null
                Start-Sleep -Seconds 2
            }

            # Start service with retry logic
            if ($nssm) {
                Write-Information "Starting service with NSSM..." -InformationAction Continue
                $startResult = & $nssm start $ServiceName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    # Check if it's already running (common race condition)
                    $statusAfterStart = & $nssm status $ServiceName 2>&1
                    if ($statusAfterStart -eq "SERVICE_RUNNING") {
                        Write-Information "Service started successfully (was already running)" -InformationAction Continue
                    } else {
                        throw "NSSM start failed: $startResult (Status: $statusAfterStart)"
                    }
                }
            } else {
                Write-Information "Starting service with standard Windows service controls..." -InformationAction Continue
                Start-Service -Name $ServiceName -ErrorAction Stop
            }

            # ENHANCED: Wait for service to start with detailed monitoring
            $maxWaitTime = 20  # Increased wait time
            $checkInterval = 2
            $elapsed = 0
            
            Write-Information "Waiting for service to start..." -InformationAction Continue
            
            while ($elapsed -lt $maxWaitTime) {
                Start-Sleep -Seconds $checkInterval
                $elapsed += $checkInterval
                
                $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                if ($service) {
                    Write-Information "Service status after $elapsed seconds: $($service.Status)" -InformationAction Continue
                    
                    if ($service.Status -eq 'Running') {
                        Write-Information "NetTrace Windows Service started successfully" -InformationAction Continue
                        
                        # Additional validation - check if service is actually working
                        Start-Sleep -Seconds 3
                        $serviceStatus = Get-ServiceStatus
                        if ($serviceStatus.IsRunning) {
                            Write-Information "Service validation successful - NetTrace monitoring is active" -InformationAction Continue
                        } else {
                            Write-Warning "Service started but NetTrace monitoring may not be active yet. Check logs if issues persist."
                        }
                        
                        return $true
                    }
                    elseif ($service.Status -eq 'Paused') {
                        # Service is paused - this usually indicates a script execution issue
                        Write-Warning "Service is in PAUSED state - this typically indicates a PowerShell script execution issue"
                        Write-Warning "Check Windows Event Logs and service logs for more details"
                        
                        # Try to get more details from NSSM
                        if ($nssm) {
                            $nssmStatus = & $nssm status $ServiceName 2>&1
                            Write-Information "NSSM status: $nssmStatus" -InformationAction Continue
                        }

                        # ENHANCED: Show recent service errors to help diagnosis
                        $serviceLogFile = "$env:ProgramData\NetTrace\service.log"
                        if (Test-Path $serviceLogFile) {
                            Write-Information "Recent service errors:" -InformationAction Continue
                            $recentErrors = Get-Content $serviceLogFile -Tail 10 | Where-Object { $_ -match "\[ERROR\]" }
                            if ($recentErrors) {
                                $recentErrors | ForEach-Object { Write-Warning "  $_" }
                            } else {
                                Write-Information "  No recent errors in service log" -InformationAction Continue
                            }
                        }
                        
                        # Check service logs
                        $logDir = "$env:ProgramData\NetTrace\service_logs"
                        $stderrLog = "$logDir\service_stderr.log"
                        
                        if (Test-Path $stderrLog) {
                            $errorContent = Get-Content $stderrLog -Tail 10 -ErrorAction SilentlyContinue
                            if ($errorContent) {
                                Write-Information "Recent service errors:" -InformationAction Continue
                                $errorContent | ForEach-Object { Write-Information "  $_" -InformationAction Continue }
                            }
                        }
                        
                        throw "Service started but is in PAUSED state. Check the service logs and Windows Event Logs for detailed error information."
                    }
                    elseif ($service.Status -eq 'Stopped') {
                        Write-Warning "Service stopped unexpectedly"
                        throw "Service stopped after starting - check Windows Event Logs and service logs for errors"
                    }
                }
            }
            
            # Final check
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service) {
                throw "Service failed to start within $maxWaitTime seconds. Final status: $($service.Status)"
            } else {
                throw "Service not found after start attempt"
            }

        } catch {
            Write-Error "Failed to start NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Stop-WindowsService {
    <#
    .SYNOPSIS
        Stops the NetTrace Windows Service
    .DESCRIPTION
        Stops the Windows Service using NSSM or standard service controls
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Stop")) {
        try {
            # Get NSSM
            $nssm = Get-NSSM

            # Check if service exists
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Information "NetTrace Windows Service is not installed" -InformationAction Continue
                return $true
            }

            # Stop service
            if ($service.Status -eq 'Running') {
                # Signal service to stop gracefully first
                Stop-NetTraceService

                Start-Sleep -Seconds 2

                # Use NSSM or standard service stop
                if ($nssm) {
                    $stopResult = & $nssm stop $ServiceName 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "NSSM stop returned: $stopResult"
                    }
                } else {
                    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                }

                # Wait for service to stop
                Start-Sleep -Seconds 3

                # Verify service is stopped
                $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                if ($service -and $service.Status -eq 'Stopped') {
                    Write-Information "NetTrace Windows Service stopped successfully" -InformationAction Continue
                    return $true
                } else {
                    Write-Warning "Service may not have stopped cleanly"
                    return $false
                }
            } else {
                Write-Information "NetTrace Windows Service is already stopped" -InformationAction Continue
                return $true
            }

        } catch {
            Write-Error "Failed to stop NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Start-NetTraceServiceRunner {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TracePath,
        [int]$MaxFiles,
        [int]$MaxSizeMB,
        [bool]$LogOutput,
        [bool]$EnableLogging
    )

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Start monitoring")) {
        Write-Information "Starting NetTrace Windows Service..." -InformationAction Continue

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
                Write-Information "Created directory: $TracePath" -InformationAction Continue
            }

            # Check if service is installed
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Information "NetTrace Windows Service is not installed. Installing automatically..." -InformationAction Continue
                $installSuccess = Install-NetTraceWindowsService
                if (-not $installSuccess) {
                    throw "Failed to install NetTrace Windows Service"
                }
            }

            # Check if service is already running
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq 'Running') {
                Write-Warning "NetTrace Windows Service is already running. Use -Stop first to stop the current session."
                return $false
            }

            # Configure the service
            $configSuccess = Start-NetTraceService -Path $TracePath -MaxFiles $MaxFiles -MaxSizeMB $MaxSizeMB -LogOutput $LogOutput -EnableLogging $EnableLogging
            if (-not $configSuccess) {
                throw "Failed to configure NetTrace service"
            }

            # Start the Windows Service
            $startSuccess = Start-WindowsService
            if (-not $startSuccess) {
                throw "Failed to start NetTrace Windows Service"
            }

            Write-Information "NetTrace Windows Service started successfully" -InformationAction Continue
            Write-Information "  Path: $TracePath" -InformationAction Continue
            Write-Information "  Max Files: $MaxFiles" -InformationAction Continue
            Write-Information "  Max Size: $MaxSizeMB MB" -InformationAction Continue
            Write-Information "  Logging: $(if ($EnableLogging) { 'Enabled' } else { 'Disabled' })" -InformationAction Continue
            Write-Information "  NetSH Output: $(if ($LogOutput) { 'Enabled' } else { 'Disabled' })" -InformationAction Continue
            Write-Information "" -InformationAction Continue
            Write-Information "Service is now running as a true Windows Service with complete persistence." -InformationAction Continue
            Write-Information "The service will survive user logouts and system reboots." -InformationAction Continue
            Write-Information "Use 'NetTrace -Stop' or 'NetTrace-ServiceRunner.ps1 -Stop' to stop the service." -InformationAction Continue

            if ($EnableLogging) {
                Write-Information "Monitor progress with: Get-Content '$TracePath\NetTrace_*.log' -Wait" -InformationAction Continue
            }

            return $true

        } catch {
            Write-Error "Error starting NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Stop-NetTraceServiceRunner {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Stop monitoring")) {
        Write-Information "Stopping NetTrace Windows Service..." -InformationAction Continue

        try {
            # Stop the Windows Service
            $stopSuccess = Stop-WindowsService
            if ($stopSuccess) {
                Write-Information "NetTrace Windows Service stopped successfully" -InformationAction Continue
                return $true
            } else {
                Write-Warning "NetTrace Windows Service may not have stopped cleanly"
                return $false
            }

        } catch {
            Write-Error "Error stopping NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Stop-WindowsService {
    <#
    .SYNOPSIS
        Stops the NetTrace Windows Service
    .DESCRIPTION
        Stops the Windows Service using NSSM or standard service controls
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Stop")) {
        try {
            # Get NSSM
            $nssm = Get-NSSM

            # Check if service exists
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Information "NetTrace Windows Service is not installed" -InformationAction Continue
                return $true
            }

            # Stop service
            if ($service.Status -eq 'Running') {
                # Signal service to stop gracefully first
                Stop-NetTraceService

                Start-Sleep -Seconds 2

                # Use NSSM or standard service stop
                if ($nssm) {
                    $stopResult = & $nssm stop $ServiceName 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warning "NSSM stop returned: $stopResult"
                    }
                } else {
                    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                }

                # Wait for service to stop
                Start-Sleep -Seconds 3

                # Verify service is stopped
                $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
                if ($service -and $service.Status -eq 'Stopped') {
                    Write-Information "NetTrace Windows Service stopped successfully" -InformationAction Continue
                    return $true
                } else {
                    Write-Warning "Service may not have stopped cleanly"
                    return $false
                }
            } else {
                Write-Information "NetTrace Windows Service is already stopped" -InformationAction Continue
                return $true
            }

        } catch {
            Write-Error "Failed to stop NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Start-NetTraceServiceRunner {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TracePath,
        [int]$MaxFiles,
        [int]$MaxSizeMB,
        [bool]$LogOutput,
        [bool]$EnableLogging
    )

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Start monitoring")) {
        Write-Information "Starting NetTrace Windows Service..." -InformationAction Continue

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
                Write-Information "Created directory: $TracePath" -InformationAction Continue
            }

            # Check if service is installed
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Information "NetTrace Windows Service is not installed. Installing automatically..." -InformationAction Continue
                $installSuccess = Install-NetTraceWindowsService
                if (-not $installSuccess) {
                    throw "Failed to install NetTrace Windows Service"
                }
            }

            # Check if service is already running
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq 'Running') {
                Write-Warning "NetTrace Windows Service is already running. Use -Stop first to stop the current session."
                return $false
            }

            # Configure the service
            $configSuccess = Start-NetTraceService -Path $TracePath -MaxFiles $MaxFiles -MaxSizeMB $MaxSizeMB -LogOutput $LogOutput -EnableLogging $EnableLogging
            if (-not $configSuccess) {
                throw "Failed to configure NetTrace service"
            }

            # Start the Windows Service
            $startSuccess = Start-WindowsService
            if (-not $startSuccess) {
                throw "Failed to start NetTrace Windows Service"
            }

            Write-Information "NetTrace Windows Service started successfully" -InformationAction Continue
            Write-Information "  Path: $TracePath" -InformationAction Continue
            Write-Information "  Max Files: $MaxFiles" -InformationAction Continue
            Write-Information "  Max Size: $MaxSizeMB MB" -InformationAction Continue
            Write-Information "  Logging: $(if ($EnableLogging) { 'Enabled' } else { 'Disabled' })" -InformationAction Continue
            Write-Information "  NetSH Output: $(if ($LogOutput) { 'Enabled' } else { 'Disabled' })" -InformationAction Continue
            Write-Information "" -InformationAction Continue
            Write-Information "Service is now running as a true Windows Service with complete persistence." -InformationAction Continue
            Write-Information "The service will survive user logouts and system reboots." -InformationAction Continue
            Write-Information "Use 'NetTrace -Stop' or 'NetTrace-ServiceRunner.ps1 -Stop' to stop the service." -InformationAction Continue

            if ($EnableLogging) {
                Write-Information "Monitor progress with: Get-Content '$TracePath\NetTrace_*.log' -Wait" -InformationAction Continue
            }

            return $true

        } catch {
            Write-Error "Error starting NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Stop-NetTraceServiceRunner {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Stop monitoring")) {
        Write-Information "Stopping NetTrace Windows Service..." -InformationAction Continue

        try {
            # Stop the Windows Service
            $stopSuccess = Stop-WindowsService
            if ($stopSuccess) {
                Write-Information "NetTrace Windows Service stopped successfully" -InformationAction Continue
                return $true
            } else {
                Write-Warning "NetTrace Windows Service may not have stopped cleanly"
                return $false
            }

        } catch {
            Write-Error "Error stopping NetTrace Windows Service: $($_.Exception.Message)"
            return $false
        }
    }
}

function Show-NetTraceServiceStatus {
    Write-Information "NetTrace Windows Service Status" -InformationAction Continue
    Write-Information "===============================" -InformationAction Continue

    try {
        # Check Windows Service status
        $windowsService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($windowsService) {
            $serviceStatusText = "Windows Service: $($windowsService.Status)"
            Write-Information $serviceStatusText -InformationAction Continue
            Write-Information "Service Type: True Windows Service (NSSM)" -InformationAction Continue
        } else {
            Write-Information "Windows Service: Not Installed" -InformationAction Continue
            Write-Information "Use -Install to install the service" -InformationAction Continue
        }

        # Check NetTrace service status
        $netTraceStatus = Get-ServiceStatus
        $netTraceStatusText = "NetTrace Service: $(if ($netTraceStatus.IsRunning) { 'Running' } else { 'Stopped' })"
        Write-Information $netTraceStatusText -InformationAction Continue

        if ($netTraceStatus.IsRunning) {
            Write-Information "" -InformationAction Continue
            Write-Information "Service Details:" -InformationAction Continue
            Write-Information "  Files Created: $($netTraceStatus.FilesCreated)" -InformationAction Continue
            Write-Information "  Files Rolled: $($netTraceStatus.FilesRolled)" -InformationAction Continue
            Write-Information "  Current File: $($netTraceStatus.CurrentFile)" -InformationAction Continue
            Write-Information "  Last Update: $($netTraceStatus.LastUpdate)" -InformationAction Continue

            if ($netTraceStatus.ErrorMessage) {
                Write-Information "  Error: $($netTraceStatus.ErrorMessage)" -InformationAction Continue
            }

            # Show configuration
            $config = Get-ServiceConfig
            if ($config) {
                Write-Information "" -InformationAction Continue
                Write-Information "Configuration:" -InformationAction Continue
                Write-Information "  Path: $($config.Path)" -InformationAction Continue
                Write-Information "  Max Files: $($config.MaxFiles)" -InformationAction Continue
                Write-Information "  Max Size: $($config.MaxSizeMB) MB" -InformationAction Continue
                Write-Information "  Logging: $(if ($config.EnableLogging) { 'Enabled' } else { 'Disabled' })" -InformationAction Continue
                Write-Information "  NetSH Output: $(if ($config.LogOutput) { 'Enabled' } else { 'Disabled' })" -InformationAction Continue
                Write-Information "  Started: $($config.StartTime)" -InformationAction Continue
                Write-Information "  Service Version: $($config.ServiceVersion)" -InformationAction Continue
            }
        } else {
            if ($netTraceStatus.ErrorMessage) {
                Write-Information "Last Error: $($netTraceStatus.ErrorMessage)" -InformationAction Continue
            }
        }

        # Show persistence information
        if ($windowsService -and $windowsService.Status -eq 'Running') {
            Write-Information "" -InformationAction Continue
            Write-Information "Persistence Status:" -InformationAction Continue
            Write-Information "  True Windows Service - survives user logouts" -InformationAction Continue
            Write-Information "  Auto-start enabled - survives system reboots" -InformationAction Continue
            Write-Information "  Service recovery configured - automatic restart on failure" -InformationAction Continue
        }

        # ENHANCED: Show validation information
        Write-Information "" -InformationAction Continue
        Write-Information "Validation Status:" -InformationAction Continue
        
        $wrapperBatch = "$env:ProgramData\NetTrace\NetTrace-Service.bat"
        $wrapperStatus = if (Test-Path $wrapperBatch) { "Found" } else { "Missing" }
        Write-Information "  Service Wrapper: $wrapperStatus" -InformationAction Continue
        
        $serviceScriptStatus = if (Test-Path $ServiceScript) { "Found" } else { "Missing" }
        Write-Information "  Service Script: $serviceScriptStatus" -InformationAction Continue
        
        $nssmPath = Get-NSSM
        $nssmStatus = if ($nssmPath) { "Available at $nssmPath" } else { "Not Available" }
        Write-Information "  NSSM: $nssmStatus" -InformationAction Continue

        return $true

    } catch {
        Write-Error "Error retrieving NetTrace Windows Service status: $($_.Exception.Message)"
        return $false
    }
}

# Main execution logic
try {
    Write-Information "NetTrace Service Runner v1.3.0" -InformationAction Continue
    Write-Information "FIXED: True Windows Service Implementation with Enhanced Reliability" -InformationAction Continue
    Write-Information "===============================" -InformationAction Continue
    Write-Information "" -InformationAction Continue

    switch ($PSCmdlet.ParameterSetName) {
        'Install' {
            if ($Install) {
                Install-NetTraceWindowsService | Out-Null
            }
        }
        'Uninstall' {
            if ($Uninstall) {
                Uninstall-NetTraceWindowsService | Out-Null
            }
        }
        'Start' {
            if ($Start) {
                Start-NetTraceServiceRunner -TracePath $Path -MaxFiles $MaxFiles -MaxSizeMB $MaxSizeMB -LogOutput:$LogOutput -EnableLogging:$EnableLogging | Out-Null
            }
        }
        'Stop' {
            if ($Stop) {
                Stop-NetTraceServiceRunner | Out-Null
            }
        }
        'Status' {
            Show-NetTraceServiceStatus | Out-Null
        }
        default {
            Show-NetTraceServiceStatus | Out-Null
        }
    }

    Write-Information "" -InformationAction Continue
    Write-Information "For more information: https://github.com/khannaveed2020/NetTrace" -InformationAction Continue

} catch {
    Write-Error "Fatal error in NetTrace Service Runner: $($_.Exception.Message)"
    exit 1
} 