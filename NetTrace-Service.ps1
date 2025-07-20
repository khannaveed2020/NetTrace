#Requires -Version 5.1

<#
.SYNOPSIS
    NetTrace Windows Service Implementation

.DESCRIPTION
    This script implements a Windows Service that provides true persistence for NetTrace functionality.
    The service handles network trace file monitoring and rotation independently of user sessions,
    ensuring continuous operation even after user logouts and system reboots.

.PARAMETER ServiceMode
    Indicates the script is running as a Windows Service. When this parameter is present,
    the script runs in service mode with direct monitoring execution.

.PARAMETER ConfigFile
    Path to the configuration file containing service parameters. Used in service mode.

.NOTES
    File Name      : NetTrace-Service.ps1
    Version        : 1.2.2
    Author         : Naveed Khan
    Company        : Hogwarts
    Copyright      : (c) 2025 Naveed Khan. All rights reserved.
    License        : MIT License
    Prerequisite   : Windows 10/11 with Administrator privileges
    Requires       : PowerShell 5.1 or PowerShell 7+

.LINK
    https://github.com/khannaveed2020/NetTrace
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$ServiceMode
)

# Service configuration
$ServiceName = "NetTraceService"

# Service state file paths
$ServiceStateDir = "$env:ProgramData\NetTrace"
$ServiceConfigFile = "$ServiceStateDir\service_config.json"
$ServiceStatusFile = "$ServiceStateDir\service_status.json"
$ServiceLogFile = "$ServiceStateDir\service.log"
$ServiceStopFlag = "$ServiceStateDir\service_stop.flag"

# Ensure service directory exists
if (!(Test-Path $ServiceStateDir)) {
    New-Item -Path $ServiceStateDir -ItemType Directory -Force | Out-Null
}

# Service logging function
function Write-ServiceLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    try {
        $logEntry | Out-File -FilePath $ServiceLogFile -Append -Encoding UTF8
    } catch {
        # Fallback to event log if file logging fails
        Write-EventLog -LogName Application -Source $ServiceName -EntryType Information -EventId 1001 -Message $Message -ErrorAction SilentlyContinue
    }
}

# Service configuration management
function Get-ServiceConfig {
    try {
        if (Test-Path $ServiceConfigFile) {
            $config = Get-Content $ServiceConfigFile -Raw | ConvertFrom-Json
            return $config
        }
    } catch {
        Write-ServiceLog "Failed to read service configuration: $($_.Exception.Message)" "ERROR"
    }
    return $null
}

function Set-ServiceConfig {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,
        [int]$MaxFiles,
        [int]$MaxSizeMB,
        [bool]$LogOutput = $false,
        [bool]$EnableLogging = $false
    )

    if ($PSCmdlet.ShouldProcess("NetTrace Service Configuration", "Save configuration")) {
        $config = @{
            Path = $Path
            MaxFiles = $MaxFiles
            MaxSizeMB = $MaxSizeMB
            LogOutput = $LogOutput
            EnableLogging = $EnableLogging
            StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ServiceVersion = "1.2.2"
        }

        try {
            $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ServiceConfigFile -Encoding UTF8
            Write-ServiceLog "Service configuration saved: Path=$Path, MaxFiles=$MaxFiles, MaxSizeMB=$MaxSizeMB"
            return $true
        } catch {
            Write-ServiceLog "Failed to save service configuration: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }
    return $false
}

# Service status management
function Get-ServiceStatus {
    try {
        if (Test-Path $ServiceStatusFile) {
            $status = Get-Content $ServiceStatusFile -Raw | ConvertFrom-Json
            return $status
        }
    } catch {
        Write-ServiceLog "Failed to read service status: $($_.Exception.Message)" "ERROR"
    }

    return @{
        IsRunning = $false
        FilesCreated = 0
        FilesRolled = 0
        CurrentFile = ""
        LastUpdate = ""
        ErrorMessage = ""
    }
}

function Set-ServiceStatus {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [bool]$IsRunning,
        [int]$FilesCreated = 0,
        [int]$FilesRolled = 0,
        [string]$CurrentFile = "",
        [string]$ErrorMessage = ""
    )

    if ($PSCmdlet.ShouldProcess("NetTrace Service Status", "Update status")) {
        $status = @{
            IsRunning = $IsRunning
            FilesCreated = $FilesCreated
            FilesRolled = $FilesRolled
            CurrentFile = $CurrentFile
            LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ErrorMessage = $ErrorMessage
        }

        try {
            $status | ConvertTo-Json -Depth 10 | Out-File -FilePath $ServiceStatusFile -Encoding UTF8
        } catch {
            Write-ServiceLog "Failed to save service status: $($_.Exception.Message)" "ERROR"
        }
    }
}

# Direct service monitoring function (replaces job-based monitoring)
function Start-DirectServiceMonitoring {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TracePath,
        [int]$MaxFiles,
        [int]$MaxSizeMB,
        [bool]$LogOutput = $false,
        [bool]$EnableLogging = $false
    )

    if ($PSCmdlet.ShouldProcess("NetTrace Service", "Start direct monitoring")) {
        Write-ServiceLog "Starting direct service monitoring: Path=$TracePath, MaxFiles=$MaxFiles, MaxSizeMB=$MaxSizeMB"

    $fileNumber = 1
    $filesCreated = 0
    $filesRolled = 0
    $fileHistory = @()
    $computerName = $env:COMPUTERNAME
    $maxSizeBytes = $MaxSizeMB * 1MB

    # Create user log file if logging is enabled
    $userLogFile = $null
    if ($EnableLogging) {
        $userLogFile = Join-Path $TracePath "NetTrace_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"
        "NetTrace persistent service started at $(Get-Date)" | Out-File -FilePath $userLogFile -Encoding UTF8
        "Command: NetTrace -Persistence true -File $MaxFiles -FileSize $MaxSizeMB -Path '$TracePath'" | Out-File -FilePath $userLogFile -Append -Encoding UTF8
        "=" * 60 | Out-File -FilePath $userLogFile -Append -Encoding UTF8
        "" | Out-File -FilePath $userLogFile -Append -Encoding UTF8
    }

    # Function to write to user log file if logging is enabled
    function Write-ToUserLog {
        param($Message, $LogFile)
        if ($LogFile) {
            try {
                $Message | Out-File -FilePath $LogFile -Append -Encoding UTF8
            } catch {
                Write-ServiceLog "Failed to write to user log file: $($_.Exception.Message)" "ERROR"
            }
        }
    }

    # Force stop any existing netsh trace to ensure clean start
    & netsh trace stop 2>&1 | Out-Null
    Start-Sleep -Seconds 2

    # Main monitoring loop - runs directly in service context
    while (-not (Test-Path $ServiceStopFlag)) {
        try {
            # Generate filename with computer name and timestamp
            $dateStamp = Get-Date -Format "dd-MM-yy"
            $timeStamp = Get-Date -Format "HHmmss"
            $traceFile = Join-Path $TracePath "$computerName`_$dateStamp-$timeStamp.etl"
            $fileName = [System.IO.Path]::GetFileName($traceFile)

            Write-ServiceLog "Creating File #$fileNumber : $fileName"
            Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - Creating File #$fileNumber : $fileName" -LogFile $userLogFile
            Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - True Windows Service persistence enabled - capture will survive user session termination" -LogFile $userLogFile

            # Start netsh trace with persistent mode
            $arguments = @("trace", "start", "capture=yes", "report=disabled", "overwrite=yes", "maxSize=$MaxSizeMB", "tracefile=`"$traceFile`"", "persistent=yes")

            $netshOutput = & netsh $arguments 2>&1
            $exitCode = $LASTEXITCODE

            # Log netsh output if requested
            if ($LogOutput) {
                $netshLogFile = Join-Path $TracePath "netsh_trace.log"
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - START TRACE (WINDOWS SERVICE):" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                $netshOutput | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                "" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
            }

            Write-ServiceLog "Netsh trace started for: $fileName (Exit Code: $exitCode)"
            Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - Netsh trace started for: $fileName" -LogFile $userLogFile

            if ($exitCode -ne 0) {
                $errorMsg = "Failed to start trace. Exit code: $exitCode"
                Write-ServiceLog $errorMsg "ERROR"
                Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - ERROR: $errorMsg" -LogFile $userLogFile
                Set-ServiceStatus -IsRunning $false -FilesCreated $filesCreated -FilesRolled $filesRolled -ErrorMessage $errorMsg
                break
            }

            $filesCreated++

            # Add current file to history
            $fileHistory += @{
                Number = $fileNumber
                Path = $traceFile
                Name = $fileName
            }

            # Update service status
            Set-ServiceStatus -IsRunning $true -FilesCreated $filesCreated -FilesRolled $filesRolled -CurrentFile $fileName

            Write-ServiceLog "Monitoring file size (limit: $MaxSizeMB MB)..."
            Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - Monitoring file size (limit: $MaxSizeMB MB)..." -LogFile $userLogFile

            # Monitor file size until limit is reached
            $fileRotated = $false
            while (-not $fileRotated -and -not (Test-Path $ServiceStopFlag)) {
                Start-Sleep -Seconds 2

                if (Test-Path $traceFile) {
                    $fileSize = (Get-Item $traceFile).Length
                    $sizeMB = [math]::Round($fileSize/1MB, 2)

                    Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - File: $fileName - Size: $sizeMB MB / $MaxSizeMB MB" -LogFile $userLogFile

                    if ($fileSize -ge $maxSizeBytes) {
                        Write-ServiceLog "Size limit reached for $fileName. Rolling to new file..."
                        Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - Size limit reached! Rolling to new file..." -LogFile $userLogFile

                        # Stop current trace
                        $stopOutput = & netsh trace stop 2>&1
                        $stopExitCode = $LASTEXITCODE

                        # Log stop output if requested
                        if ($LogOutput) {
                            $netshLogFile = Join-Path $TracePath "netsh_trace.log"
                            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - STOP TRACE (WINDOWS SERVICE):" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                            $stopOutput | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                            "" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                        }

                        Write-ServiceLog "Trace stopped for file: $fileName (Exit Code: $stopExitCode)"
                        Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - Trace stopped for file: $fileName" -LogFile $userLogFile

                        if ($stopExitCode -eq 0) {
                            $filesRolled++
                            $fileRotated = $true
                            $fileNumber++

                            # Circular file management
                            if ($fileHistory.Count -gt $MaxFiles) {
                                $oldestFile = $fileHistory[0]
                                if (Test-Path $oldestFile.Path) {
                                    Remove-Item $oldestFile.Path -Force -ErrorAction SilentlyContinue
                                    Write-ServiceLog "Removed oldest file: $($oldestFile.Name)"
                                    Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - Removed oldest file: $($oldestFile.Name)" -LogFile $userLogFile
                                }
                                $fileHistory = $fileHistory[1..($fileHistory.Count-1)]
                            }

                            # Update service status
                            Set-ServiceStatus -IsRunning $true -FilesCreated $filesCreated -FilesRolled $filesRolled -CurrentFile ""
                        } else {
                            $errorMsg = "Failed to stop trace. Exit code: $stopExitCode"
                            Write-ServiceLog $errorMsg "ERROR"
                            Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - ERROR: $errorMsg" -LogFile $userLogFile
                            Set-ServiceStatus -IsRunning $false -FilesCreated $filesCreated -FilesRolled $filesRolled -ErrorMessage $errorMsg
                            break
                        }
                    }
                } else {
                    $errorMsg = "Trace file not found: $traceFile"
                    Write-ServiceLog $errorMsg "ERROR"
                    Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - ERROR: $errorMsg" -LogFile $userLogFile
                    Set-ServiceStatus -IsRunning $false -FilesCreated $filesCreated -FilesRolled $filesRolled -ErrorMessage $errorMsg
                    break
                }
            }
        } catch {
            $errorMsg = "Service monitoring error: $($_.Exception.Message)"
            Write-ServiceLog $errorMsg "ERROR"
            Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - ERROR: $errorMsg" -LogFile $userLogFile
            Set-ServiceStatus -IsRunning $false -FilesCreated $filesCreated -FilesRolled $filesRolled -ErrorMessage $errorMsg
            break
        }
    }

    # Cleanup when service stops
    Write-ServiceLog "Service monitoring stopped. Cleaning up..."
    Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - Service monitoring stopped" -LogFile $userLogFile
    Write-ToUserLog -Message "$(Get-Date -Format 'HH:mm:ss') - SUMMARY: Files created: $filesCreated, Files rolled: $filesRolled" -LogFile $userLogFile
    Write-ToUserLog -Message ("=" * 60) -LogFile $userLogFile

    & netsh trace stop 2>&1 | Out-Null
    Set-ServiceStatus -IsRunning $false -FilesCreated $filesCreated -FilesRolled $filesRolled -CurrentFile ""

    # Remove stop flag
    if (Test-Path $ServiceStopFlag) {
        Remove-Item $ServiceStopFlag -Force -ErrorAction SilentlyContinue
    }
    }
}

# Service control functions (NEW: No longer uses jobs)
function Start-NetTraceService {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,
        [int]$MaxFiles,
        [int]$MaxSizeMB,
        [bool]$LogOutput = $false,
        [bool]$EnableLogging = $false
    )

    if ($PSCmdlet.ShouldProcess("NetTrace Service", "Start service")) {
        Write-ServiceLog "Service start requested: Path=$Path, MaxFiles=$MaxFiles, MaxSizeMB=$MaxSizeMB"

        # Check if service is already running
        $currentStatus = Get-ServiceStatus
        if ($currentStatus.IsRunning) {
            Write-ServiceLog "Service is already running" "WARNING"
            return $false
        }

        # Remove any existing stop flag
        if (Test-Path $ServiceStopFlag) {
            Remove-Item $ServiceStopFlag -Force -ErrorAction SilentlyContinue
        }

        # Save configuration for service to read
        if (-not (Set-ServiceConfig -Path $Path -MaxFiles $MaxFiles -MaxSizeMB $MaxSizeMB -LogOutput $LogOutput -EnableLogging $EnableLogging)) {
            Write-ServiceLog "Failed to save service configuration" "ERROR"
            return $false
        }

        Write-ServiceLog "Service configuration saved. Ready for Windows Service to start."
        return $true
    }
    return $false
}

function Stop-NetTraceService {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NetTrace Service", "Stop service")) {
        Write-ServiceLog "Service stop requested"

        # Create stop flag to signal service to stop
        try {
            "stop" | Out-File -FilePath $ServiceStopFlag -Force
            Write-ServiceLog "Service stop flag created"
        } catch {
            Write-ServiceLog "Failed to create service stop flag: $($_.Exception.Message)" "ERROR"
        }

        # Stop any running netsh trace
        & netsh trace stop 2>&1 | Out-Null
        Write-ServiceLog "Netsh trace stopped"

        # Update status
        $currentStatus = Get-ServiceStatus
        Set-ServiceStatus -IsRunning $false -FilesCreated $currentStatus.FilesCreated -FilesRolled $currentStatus.FilesRolled

        Write-ServiceLog "Service stopped successfully"
        return $true
    }
    return $false
}

# Service mode execution
if ($ServiceMode) {
    Write-ServiceLog "Starting in Windows Service Mode"

    # Read configuration
    $config = Get-ServiceConfig
    if (-not $config) {
        Write-ServiceLog "No service configuration found" "ERROR"
        exit 1
    }

    Write-ServiceLog "Service configuration loaded: Path=$($config.Path), MaxFiles=$($config.MaxFiles), MaxSizeMB=$($config.MaxSizeMB)"

    # Start direct monitoring (no jobs)
    try {
        Start-DirectServiceMonitoring -TracePath $config.Path -MaxFiles $config.MaxFiles -MaxSizeMB $config.MaxSizeMB -LogOutput $config.LogOutput -EnableLogging $config.EnableLogging
    } catch {
        Write-ServiceLog "Service monitoring failed: $($_.Exception.Message)" "ERROR"
        exit 1
    }

    Write-ServiceLog "Service mode execution completed"
    exit 0
}

# Export functions for use by other scripts
Export-ModuleMember -Function Start-NetTraceService, Stop-NetTraceService, Get-ServiceStatus, Get-ServiceConfig, Write-ServiceLog

# If script is run directly without service mode, provide guidance
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Write-Information "NetTrace Service Script v1.2.2" -InformationAction Continue
    Write-Information "This script now implements a true Windows Service using NSSM." -InformationAction Continue
    Write-Information "This script should be used through NetTrace-ServiceRunner.ps1 for proper service management." -InformationAction Continue
    Write-Information "Direct execution without -ServiceMode is not recommended." -InformationAction Continue
}