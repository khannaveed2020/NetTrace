#Requires -Version 5.1

<#
.SYNOPSIS
    NetTrace PowerShell Module for Windows Network Tracing

.DESCRIPTION
    A PowerShell module that provides functionality to perform network traces using Windows native Netsh utility.
    Creates multiple trace files with automatic circular rotation based on file size limits. Features non-blocking
    operation, comprehensive logging, and background monitoring for optimal performance.

.NOTES
    File Name      : NetTrace.psm1
    Version        : 1.3.4
    Author         : Naveed Khan
    Company        : Hogwarts
    Copyright      : (c) 2025 Naveed Khan. All rights reserved.
    License        : MIT License
    Prerequisite   : Windows 10/11 with Netsh utility
    Requires       : Administrator privileges
    Compatibility  : PowerShell 5.1 and PowerShell 7+

.LINK
    https://github.com/khannaveed2020/NetTrace

.LINK
    https://github.com/khannaveed2020/NetTrace/blob/main/README.md
#>

# Module variables
$script:IsTracing = $false
$script:TraceJob = $null
$script:TracePath = $null
$script:MaxFiles = 0
$script:MaxSizeMB = 0
$script:FilesCreated = 0
$script:FilesRolled = 0
$script:CurrentLogFile = $null
$script:MonitorFlag = $null
$script:CounterFile = $null
$script:PersistenceEnabled = $false

<#
.SYNOPSIS
    Starts a network trace using netsh trace with automatic file rotation

.DESCRIPTION
    Starts a network trace with circular file management. Creates files up to the specified
    limit, then replaces the oldest file when a new one is needed. Continues until manually stopped.

.PARAMETER File
    Maximum number of trace files to maintain simultaneously. When this limit is reached,
    the oldest file is deleted when creating a new one (circular buffer behavior).

.PARAMETER FileSize
    Maximum size of each trace file in MB. Must be at least 10 MB (netsh trace limitation).
    When a file reaches this size, it rotates to a new file.

.PARAMETER Path
    Directory path where trace files will be stored.

.PARAMETER Stop
    Stops the currently running trace.

.PARAMETER LogNetshOutput
    Logs all netsh trace output to a file named 'netsh_trace.log' in the trace directory.
    This suppresses console output while preserving it for troubleshooting.

.PARAMETER Log
    When specified, enables detailed logging of all trace operations to a log file.
    Without this parameter, the module operates without creating log files, reducing disk I/O.
    Recommended for troubleshooting or monitoring trace progress.

.PARAMETER Persistence
    When set to true, enables persistent capture that will automatically resume after a system reboot.
    This feature utilizes the native netsh trace 'persistent=yes' parameter. When enabled, the capture
    will continue even if the user session is terminated or the system is rebooted. It's recommended
    to use FileSize >= 10MB when persistence is enabled to avoid potential issues.

    Accepts multiple formats: $true/$false, true/false, or "true"/"false" (case-insensitive).

.PARAMETER Verbose
    Shows detailed information about files created, rolled, and deleted during circular management.

.EXAMPLE
    NetTrace -File 2 -FileSize 10 -Path "C:\Traces"

    Creates up to 2 files of 10MB each in C:\Traces directory. When the 3rd file is needed,
    automatically deletes the oldest file (circular buffer management). Runs in background
    with non-blocking console operation.

.EXAMPLE
    NetTrace -File 5 -FileSize 50 -Path "C:\Traces" -Verbose

    Maintains 5 files of 50MB each with detailed verbose output showing file creation,
    rotation, and deletion activities. Perfect for monitoring file management behavior.

.EXAMPLE
    NetTrace -File 3 -FileSize 25 -Path "D:\NetworkTraces" -LogNetshOutput

    Creates 3 trace files of 25MB each in D:\NetworkTraces directory. All netsh trace
    output is logged to D:\NetworkTraces\netsh_trace.log for troubleshooting purposes.

.EXAMPLE
    NetTrace -File 4 -FileSize 15 -Path "C:\Traces" -Log

    Creates up to 4 files of 15MB each with detailed logging enabled. Progress and file
    operations are logged to C:\Traces\NetTrace_*.log for monitoring and troubleshooting.

.EXAMPLE
    NetTrace -Stop

    Stops the currently running network trace session and performs cleanup of background
    processes. Returns summary information about files created and rotated.

.EXAMPLE
    # Start tracing with monitoring
    NetTrace -File 4 -FileSize 20 -Path "C:\Traces"
    Get-Content "C:\Traces\NetTrace_*.log" -Wait

    Starts network tracing and simultaneously monitors the log file for real-time activity.
    Use Ctrl+C to stop monitoring, then use 'NetTrace -Stop' to stop the trace or 'Get-NetTraceStatus' to check status.

.EXAMPLE
    NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence true

    Creates a persistent network trace that will continue even after system reboot.
    Maintains 3 files of 10MB each with automatic circular rotation. The capture will
    automatically resume after reboot, making it ideal for long-running captures.
#>
function NetTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$File,

        [Parameter(Mandatory=$false)]
        [int]$FileSize,

        [Parameter(Mandatory=$false)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [switch]$Stop,

        [Parameter(Mandatory=$false)]
        [switch]$LogNetshOutput,

        [Parameter(Mandatory=$false)]
        [switch]$Log,

        [Parameter(Mandatory=$false)]
        [ValidateSet('true', 'false', '$true', '$false', $true, $false)]
        [object]$Persistence = $false
    )

    try {
        # Check for administrator privileges
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$currentUser
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            throw "This module requires Administrator privileges. Please run PowerShell as Administrator."
        }

        # Handle stop request
        if ($Stop) {
            Stop-NetTraceCapture
            return
        }

        # Validate parameters
        if ($File -le 0) {
            throw "File parameter must be a positive integer"
        }
        if ($FileSize -le 0) {
            throw "FileSize parameter must be a positive integer"
        }
        if ($FileSize -lt 10) {
            throw "FileSize must be at least 10 MB. Netsh trace has a minimum file size of 10MB - smaller values default to 512MB."
        }
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw "Path parameter is required"
        }

        # Convert persistence parameter to boolean if it's a string
        if ($Persistence -is [string]) {
            $Persistence = $Persistence.ToLower() -eq 'true' -or $Persistence.ToLower() -eq '$true'
        }

        # Validate persistence parameter
        if ($Persistence -and $FileSize -lt 10) {
            Write-Warning "Persistence is enabled but FileSize is less than 10MB. For persistent captures, it's recommended to use FileSize >= 10MB to avoid potential issues."
        }

        # Ensure directory exists
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            if ($VerbosePreference -eq 'Continue') {
                Write-Verbose "Created directory: $Path"
            }
        }

        # Check if already tracing
        if ($script:IsTracing) {
            Write-Warning "A trace is already running. Use NetTrace -Stop first."
            return
        }

        # Determine which persistence mode to use
        if ($Persistence) {
            # CRITICAL FIX: Correct parameter mapping and type conversion
            Write-Information "DEBUG: Calling Start-NetTraceServicePersistence with Path='$Path', File=$File, FileSize=$FileSize, LogNetshOutput=$LogNetshOutput, Log=$Log" -InformationAction Continue
            Start-NetTraceServicePersistence -Path $Path -MaxFiles $File -MaxSizeMB $FileSize -LogOutput ([bool]$LogNetshOutput) -EnableLogging ([bool]$Log)
        } else {
            # Use job-based approach for non-persistent traces
            Start-NetTraceCapture -Path $Path -MaxFiles $File -MaxSizeMB $FileSize -LogOutput:$LogNetshOutput -EnableLogging:$Log -Persistence:$Persistence
        }
    }
    catch {
        Write-Error "Error in NetTrace: $($_.Exception.Message)"
        throw
    }
}

function Start-NetTraceCapture {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Collections.Hashtable])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LogOutput', Justification='Parameter is used in background job script block')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$MaxFiles,

        [Parameter(Mandatory)]
        [int]$MaxSizeMB,

        [Parameter()]
        [bool]$LogOutput = $false, # Used in background job script block

        [Parameter()]
        [bool]$EnableLogging = $false,

        [Parameter()]
        [ValidateSet('true', 'false', '$true', '$false', $true, $false)]
        [object]$Persistence = $false
    )

    try {
        # Convert persistence parameter to boolean if it's a string
        if ($Persistence -is [string]) {
            $Persistence = $Persistence.ToLower() -eq 'true' -or $Persistence.ToLower() -eq '$true'
        }

        $script:TracePath = $Path
        $script:MaxFiles = $MaxFiles
        $script:MaxSizeMB = $MaxSizeMB
        $script:FilesCreated = 0
        $script:FilesRolled = 0
        $script:PersistenceEnabled = $Persistence

        if ($VerbosePreference -eq 'Continue') {
            Write-Information "Starting network trace..." -InformationAction Continue
            Write-Information "Path: $Path" -InformationAction Continue
            Write-Information "Max Files: $MaxFiles" -InformationAction Continue
            Write-Information "Max Size: $MaxSizeMB MB" -InformationAction Continue
            if ($Persistence) {
                Write-Information "Persistence: Enabled (capture will resume after reboot)" -InformationAction Continue
            }
        }

        # Create log file for all output if logging is enabled
        if ($EnableLogging) {
            $script:CurrentLogFile = Join-Path $Path "NetTrace_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"
            "NetTrace session started at $(Get-Date)" | Out-File -FilePath $script:CurrentLogFile -Encoding UTF8
            $commandLine = "Command: NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path '$Path'"
            if ($Persistence) {
                $commandLine += " -Persistence true"
            }
            $commandLine | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
            "=" * 60 | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
            "" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
        } else {
            $script:CurrentLogFile = $null
        }

        # Create counter file for tracking counts
        $script:CounterFile = Join-Path $Path ".nettrace_counters"
        "0,0," | Out-File -FilePath $script:CounterFile -Encoding UTF8

        # Force stop any existing netsh trace to ensure clean start (non-blocking)
        Start-Job -ScriptBlock { & netsh trace stop 2>&1 | Out-Null } | Out-Null

        # Get computer name and calculate max size in bytes
        $computerName = $env:COMPUTERNAME
        $maxSizeBytes = $MaxSizeMB * 1MB

        # Create monitoring flag for stop functionality
        $script:MonitorFlag = [System.Threading.ManualResetEvent]::new($false)
        $script:IsTracing = $true

        # Show initial message
        if ($VerbosePreference -eq 'Continue') {
            Write-Information "Network trace started successfully with circular file management." -InformationAction Continue
            Write-Information "Will maintain $MaxFiles files of $MaxSizeMB MB each, replacing oldest when full." -InformationAction Continue
            Write-Information "Use 'NetTrace -Stop' to stop." -InformationAction Continue
        }

        # Start background job for file monitoring
        $script:TraceJob = Start-Job -ScriptBlock {
            # Use Using: scope for variables passed from parent scope
            $TracePath = $using:Path
            $MaxFiles = $using:MaxFiles
            $MaxSizeMB = $using:MaxSizeMB
            $LogOutput = $using:LogOutput
            $LogFile = $using:script:CurrentLogFile
            $CounterFile = $using:script:CounterFile
            $Persistence = $using:Persistence

            $fileNumber = 1
            $filesCreated = 0
            $filesRolled = 0
            $fileHistory = @()  # Track created files for circular management
            $computerName = $env:COMPUTERNAME
            $maxSizeBytes = $MaxSizeMB * 1MB

            # Function to save counter file with current file name
            function Save-CounterFile {
                param($FilesCreated, $FilesRolled, $CounterFile, $CurrentFile = "")
                try {
                    "$FilesCreated,$FilesRolled,$CurrentFile" | Out-File -FilePath $CounterFile -Encoding UTF8
                } catch {
                    Write-Error "Failed to update counter file: $($_.Exception.Message)"
                }
            }

            # Function to write to log file if logging is enabled
            function Write-ToLog {
                param($Message, $LogFile)
                if ($LogFile) {
                    try {
                        $Message | Out-File -FilePath $LogFile -Append -Encoding UTF8
                    } catch {
                        Write-Error "Failed to write to log file: $($_.Exception.Message)"
                    }
                }
            }

            # Create flag file to check if we should continue
            $flagFile = Join-Path $TracePath ".nettrace_running"
            "running" | Out-File -FilePath $flagFile -Force

            # Small delay to ensure any previous netsh stop command has completed
            Start-Sleep -Seconds 1

            # Create files continuously with circular management
            while (Test-Path $flagFile) {
                # Generate filename with computer name and timestamp
                $dateStamp = Get-Date -Format "dd-MM-yy"
                $timeStamp = Get-Date -Format "HHmmss"
                $traceFile = Join-Path $TracePath "$computerName`_$dateStamp-$timeStamp.etl"
                $fileName = [System.IO.Path]::GetFileName($traceFile)

                # Log file creation
                Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Creating File #$fileNumber : $fileName" -LogFile $LogFile
                if ($Persistence) {
                    Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Persistence enabled - capture will resume after reboot" -LogFile $LogFile
                }

                # Start netsh trace with report disabled and no additional data capture
                $arguments = @("trace", "start", "capture=yes", "report=disabled", "overwrite=yes", "maxSize=$MaxSizeMB", "tracefile=`"$traceFile`"")

                # Add persistent parameter if persistence is enabled
                if ($Persistence) {
                    $arguments += "persistent=yes"
                }

                # Execute netsh and capture output to suppress console spam
                $netshOutput = & netsh $arguments 2>&1
                $process = [PSCustomObject]@{ ExitCode = $LASTEXITCODE }

                # Log netsh output to file if requested
                if ($LogOutput) {
                    $netshLogFile = Join-Path $TracePath "netsh_trace.log"
                    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - START TRACE:" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                    $netshOutput | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                    "" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                }

                # Always log to main log file
                Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Netsh trace started for: $fileName" -LogFile $LogFile

                if ($process.ExitCode -ne 0) {
                    Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - ERROR: Failed to start trace. Exit code: $($process.ExitCode)" -LogFile $LogFile
                    break
                }

                $filesCreated++
                Save-CounterFile -FilesCreated $filesCreated -FilesRolled $filesRolled -CounterFile $CounterFile -CurrentFile $fileName

                # Add current file to history
                $fileHistory += @{
                    Number = $fileNumber
                    Path = $traceFile
                    Name = $fileName
                }

                Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Monitoring file size (limit: $MaxSizeMB MB)..." -LogFile $LogFile

                # Monitor this specific file until it reaches size limit
                $fileRotated = $false

                while (-not $fileRotated -and (Test-Path $flagFile)) {
                    # Use shorter sleep for better responsiveness and accuracy
                    Start-Sleep -Milliseconds 500

                    if (Test-Path $traceFile) {
                        $fileSize = (Get-Item $traceFile).Length

                        $sizeMB = [math]::Round($fileSize/1MB, 2)
                        Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - File: $fileName - Size: $sizeMB MB / $MaxSizeMB MB" -LogFile $LogFile

                        if ($fileSize -ge $maxSizeBytes) {
                            # Size limit reached, rotate to next file
                            Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Size limit reached! Rolling to new file..." -LogFile $LogFile

                            # Stop current trace
                            $stopOutput = & netsh trace stop 2>&1
                            $stopProcess = [PSCustomObject]@{ ExitCode = $LASTEXITCODE }

                            # Log stop output if requested
                            if ($LogOutput) {
                                $netshLogFile = Join-Path $TracePath "netsh_trace.log"
                                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - STOP TRACE:" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                                $stopOutput | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                                "" | Out-File -FilePath $netshLogFile -Append -Encoding UTF8
                            }

                            # Always log to main log file
                            Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Trace stopped for file: $fileName" -LogFile $LogFile

                            if ($stopProcess.ExitCode -eq 0) {
                                $filesRolled++
                                $fileRotated = $true
                                $fileNumber++

                                # Circular file management: remove oldest file if we exceed MaxFiles
                                if ($fileHistory.Count -gt $MaxFiles) {
                                    $oldestFile = $fileHistory[0]
                                    if (Test-Path $oldestFile.Path) {
                                        Remove-Item $oldestFile.Path -Force -ErrorAction SilentlyContinue
                                        Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Removed oldest file: $($oldestFile.Name)" -LogFile $LogFile
                                    }
                                    # Remove from history
                                    $fileHistory = $fileHistory[1..($fileHistory.Count-1)]
                                }

                                # Update counter file after rotation (no current file during rotation)
                                Save-CounterFile -FilesCreated $filesCreated -FilesRolled $filesRolled -CounterFile $CounterFile -CurrentFile ""
                            } else {
                                Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - ERROR: Failed to stop trace. Exit code: $($stopProcess.ExitCode)" -LogFile $LogFile
                                break
                            }
                        }
                    } else {
                        Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - ERROR: Trace file not found: $traceFile" -LogFile $LogFile
                        break
                    }
                }
            }

            # Stop trace when manually stopped
            & netsh trace stop 2>&1 | Out-Null

            # Output summary to log
            Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - Trace session ended" -LogFile $LogFile
            Write-ToLog -Message "$(Get-Date -Format 'HH:mm:ss') - SUMMARY: Files created: $filesCreated, Files rolled: $filesRolled" -LogFile $LogFile
            Write-ToLog -Message ("=" * 60) -LogFile $LogFile

        }

        Write-Information "Trace monitoring started in background." -InformationAction Continue
        if ($EnableLogging) {
            Write-Information "All output is being logged to: $($script:CurrentLogFile)" -InformationAction Continue
            Write-Information "You can monitor progress with: Get-Content '$($script:CurrentLogFile)' -Wait" -InformationAction Continue
        } else {
            Write-Information "Logging is disabled. Use -Log parameter to enable detailed logging." -InformationAction Continue
        }
        Write-Information "Use 'NetTrace -Stop' to stop the trace or 'Get-NetTraceStatus' to check status." -InformationAction Continue

        # Wait for the background job to create the first file and update counters
        Start-Sleep -Seconds 3

        # Get current counts from counter file
        $currentCounts = Get-CurrentCount

        # Return summary information
        return @{
            FilesCreated = $currentCounts.FilesCreated
            FilesRolled = $currentCounts.FilesRolled
            Success = $true
            Persistence = $Persistence
        }
    }
    catch {
        Write-Error "Error starting network trace: $($_.Exception.Message)"
        throw
    }
}

function Start-NetTraceServicePersistence {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$MaxFiles,

        [Parameter(Mandatory)]
        [int]$MaxSizeMB,

        [Parameter()]
        [bool]$LogOutput = $false,

        [Parameter()]
        [bool]$EnableLogging = $false
    )

    try {
        # Check if we should process
        if ($PSCmdlet.ShouldProcess("NetTrace Windows Service", "Start persistent network trace")) {
            # Get script directory to find service files - they are in the same directory as the module
            $moduleDir = $PSScriptRoot
            if (-not $moduleDir) {
                $moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
            }

            $serviceRunnerScript = Join-Path $moduleDir "NetTrace-ServiceRunner.ps1"

            # Check if service runner script exists
            if (!(Test-Path $serviceRunnerScript)) {
                throw "NetTrace-ServiceRunner.ps1 not found. Windows Service persistence requires the service runner script to be available."
            }

            if ($VerbosePreference -eq 'Continue') {
                Write-Information "Starting Windows Service persistent network trace..." -InformationAction Continue
                Write-Information "Path: $Path" -InformationAction Continue
                Write-Information "Max Files: $MaxFiles" -InformationAction Continue
                Write-Information "Max Size: $MaxSizeMB MB" -InformationAction Continue
                Write-Information "True Windows Service persistence: Enabled (capture will survive user session termination and system reboots)" -InformationAction Continue
            }

            # Import service runner functions for proper Windows Service management
            . $serviceRunnerScript

            # Check if service is installed, install if needed
            $service = Get-Service -Name "NetTraceService" -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Information "NetTrace Windows Service is not installed. Installing automatically..." -InformationAction Continue
                $installSuccess = Install-NetTraceWindowsService
                if (-not $installSuccess) {
                    throw "Failed to install NetTrace Windows Service"
                }
            }

            # Check if service is already running
            $service = Get-Service -Name "NetTraceService" -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq 'Running') {
                Write-Warning "NetTrace Windows Service is already running. Use 'NetTrace -Stop' first to stop the current session."
                throw "Service is already running"
            }

            # Configure the service - ENHANCED: Direct configuration creation with parameter validation
            $serviceStateDir = "$env:ProgramData\NetTrace"
            if (!(Test-Path $serviceStateDir)) {
                New-Item -Path $serviceStateDir -ItemType Directory -Force | Out-Null
            }

            # CRITICAL FIX: Validate parameters are not empty before creating config
            if ([string]::IsNullOrWhiteSpace($Path)) {
                throw "Path parameter is empty. This indicates a parameter passing issue."
            }
            if ($MaxFiles -eq 0) {
                throw "MaxFiles parameter is zero. This indicates a parameter passing issue."
            }
            if ($MaxSizeMB -eq 0) {
                throw "MaxSizeMB parameter is zero. This indicates a parameter passing issue."
            }

            # Debug logging for parameter validation
            Write-Information "Creating service configuration with parameters:" -InformationAction Continue
            Write-Information "  Path: '$Path'" -InformationAction Continue
            Write-Information "  MaxFiles: $MaxFiles" -InformationAction Continue
            Write-Information "  MaxSizeMB: $MaxSizeMB" -InformationAction Continue
            Write-Information "  LogOutput: $LogOutput" -InformationAction Continue
            Write-Information "  EnableLogging: $EnableLogging" -InformationAction Continue

            $config = @{
                Path = $Path
                MaxFiles = $MaxFiles
                MaxSizeMB = $MaxSizeMB
                LogOutput = [bool]$LogOutput
                EnableLogging = [bool]$EnableLogging
                StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ServiceVersion = "1.3.4"
            }

            $serviceConfigFile = "$serviceStateDir\service_config.json"
            try {
                $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $serviceConfigFile -Encoding UTF8
                Write-Information "Service configuration created successfully with validated parameters" -InformationAction Continue
            } catch {
                throw "Failed to save service configuration: $($_.Exception.Message)"
            }

            # Start the Windows Service
            $startSuccess = Start-WindowsService
            if (-not $startSuccess) {
                throw "Failed to start NetTrace Windows Service"
            }

            Write-Information "Windows Service persistent trace started successfully." -InformationAction Continue
            Write-Information "  Path: $Path" -InformationAction Continue
            Write-Information "  Max Files: $MaxFiles" -InformationAction Continue
            Write-Information "  Max Size: $MaxSizeMB MB" -InformationAction Continue
            Write-Information "  True Windows Service persistence: Enabled (capture will survive user session termination and system reboots)" -InformationAction Continue
            
            if ($EnableLogging) {
                $logFile = Join-Path $Path "NetTrace_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"
                Write-Information "All output is being logged to: $logFile" -InformationAction Continue
                Write-Information "You can monitor progress with: Get-Content '$Path\NetTrace_*.log' -Wait" -InformationAction Continue
            } else {
                Write-Information "Logging is disabled. Use -Log parameter to enable detailed logging." -InformationAction Continue
            }
            Write-Information "Use 'NetTrace -Stop' to stop the Windows Service trace or 'Get-NetTraceStatus' to check status." -InformationAction Continue

            # Wait a moment for Windows Service to initialize
            Start-Sleep -Seconds 5

            # Get current status from Windows Service
            $serviceStatus = Get-WindowsServiceStatus

            return @{
                FilesCreated = $serviceStatus.FilesCreated
                FilesRolled = $serviceStatus.FilesRolled
                Success = $true
                Persistence = $true
                Mode = "WindowsService"
            }
        }
    }
    catch {
        Write-Error "Error starting Windows Service persistent network trace: $($_.Exception.Message)"
        throw
    }
}

function Get-WindowsServiceStatus {
    <#
    .SYNOPSIS
        Gets the current status of the NetTrace Windows Service
    .DESCRIPTION
        Retrieves status information from the Windows Service including files created, rolled, and current file
    #>

    try {
        # Get script directory to find service files
        $moduleDir = $PSScriptRoot
        if (-not $moduleDir) {
            $moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        }

        $serviceScript = Join-Path $moduleDir "NetTrace-Service.ps1"

        # Check if service script exists
        if (!(Test-Path $serviceScript)) {
            return @{
                FilesCreated = 0
                FilesRolled = 0
                CurrentFile = ""
                LastUpdate = ""
                ErrorMessage = "Service script not found"
            }
        }

        # Import service functions
        . $serviceScript

        # Get status from Windows Service
        $serviceStatus = Get-ServiceStatus

        return $serviceStatus
    }
    catch {
        return @{
            FilesCreated = 0
            FilesRolled = 0
            CurrentFile = ""
            LastUpdate = ""
            ErrorMessage = $_.Exception.Message
        }
    }
}

function Get-CurrentCount {
    try {
        if ($script:CounterFile -and (Test-Path $script:CounterFile)) {
            $content = Get-Content $script:CounterFile -ErrorAction SilentlyContinue
            if ($content) {
                $parts = $content.Split(',')
                if ($parts.Count -eq 3) {
                    return @{
                        FilesCreated = [int]$parts[0]
                        FilesRolled = [int]$parts[1]
                        CurrentFile = $parts[2]
                    }
                }
            }
        }
    } catch {
        Write-Error "Failed to read counter file: $($_.Exception.Message)"
    }

    return @{
        FilesCreated = 0
        FilesRolled = 0
        CurrentFile = ""
    }
}

function Stop-NetTraceCapture {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Collections.Hashtable])]
    param()

    try {
        if ($VerbosePreference -eq 'Continue') {
            Write-Information "Stopping network trace..." -InformationAction Continue
        }

        # Check if Windows Service persistence is running
        $serviceRunning = $false
        try {
            $moduleDir = $PSScriptRoot
            if (-not $moduleDir) {
                $moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
            }

            # Check if Windows Service is running
            $windowsService = Get-Service -Name "NetTraceService" -ErrorAction SilentlyContinue
            if ($windowsService -and $windowsService.Status -eq 'Running') {
                $serviceRunning = $true
            }
        } catch {
            # Service not available or error checking status
            $serviceRunning = $false
        }

        if ($serviceRunning) {
            # Stop Windows Service persistence
            Write-Information "Stopping Windows Service persistent trace..." -InformationAction Continue

            $serviceRunnerScript = Join-Path $moduleDir "NetTrace-ServiceRunner.ps1"
            if (Test-Path $serviceRunnerScript) {
                # Import service runner functions for proper Windows Service management
                . $serviceRunnerScript

                # Stop the Windows Service properly
                $stopSuccess = Stop-WindowsService
                
                if ($stopSuccess) {
                    Write-Information "Windows Service persistent trace stopped." -InformationAction Continue
                    $finalStatus = Get-WindowsServiceStatus
                    return @{
                        Success = $true
                        FilesCreated = $finalStatus.FilesCreated
                        FilesRolled = $finalStatus.FilesRolled
                        Persistence = $true
                        Mode = "WindowsService"
                    }
                } else {
                    return @{
                        Success = $false
                        Error = "Failed to stop Windows Service persistence"
                        Mode = "WindowsService"
                    }
                }
            } else {
                return @{
                    Success = $false
                    Error = "NetTrace-ServiceRunner.ps1 not found"
                    Mode = "WindowsService"
                }
            }
        }

        # Continue with job-based stopping
        # Set the flag to stop monitoring
        $script:IsTracing = $false

        # Remove flag file to stop background job FIRST
        if ($script:TracePath) {
            $flagFile = Join-Path $script:TracePath ".nettrace_running"
            Remove-Item $flagFile -Force -ErrorAction SilentlyContinue
        }

        # Give background job time to see the flag removal and stop gracefully
        Start-Sleep -Milliseconds 1000

        # Check if trace is still running first
        $statusOutput = & netsh trace show status 2>&1
        $isTraceRunning = $statusOutput -notmatch "no trace session currently in progress"

        $stopSuccess = $true  # Assume success by default

        if ($isTraceRunning) {
            # Stop netsh trace (try multiple times if needed due to potential race conditions)
            $stopAttempts = 0
            $maxAttempts = 3
            $stopSuccess = $false

            while ($stopAttempts -lt $maxAttempts -and -not $stopSuccess) {
                $stopAttempts++
                & netsh trace stop 2>&1 | Out-Null
                $process = [PSCustomObject]@{ ExitCode = $LASTEXITCODE }

                if ($process.ExitCode -eq 0) {
                    $stopSuccess = $true
                } else {
                    # If first attempt fails, wait a bit and try again
                    if ($stopAttempts -lt $maxAttempts) {
                        Start-Sleep -Milliseconds 500
                    }
                }
            }
        } else {
            # Trace is already stopped, so we're successful
            $process = [PSCustomObject]@{ ExitCode = 0 }
        }

        if ($stopSuccess) {
            Write-Information "Trace stopped." -InformationAction Continue

            # Log the stop action
            if ($script:CurrentLogFile -and (Test-Path $script:CurrentLogFile)) {
                "$(Get-Date -Format 'HH:mm:ss') - Manual stop command received" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
                "$(Get-Date -Format 'HH:mm:ss') - NetTrace session ended by user" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
                Write-Information "Final logs saved to: $($script:CurrentLogFile)" -InformationAction Continue
            }

            # Get final counts from counter file
            $finalCounts = Get-CurrentCount

            return @{
                Success = $true
                FilesCreated = $finalCounts.FilesCreated
                FilesRolled = $finalCounts.FilesRolled
                Persistence = $script:PersistenceEnabled
                Mode = "Job"
            }
        } else {
            if ($VerbosePreference -eq 'Continue') {
                Write-Warning "Failed to stop trace after $stopAttempts attempts. Last exit code: $($process.ExitCode)"
            } else {
                Write-Warning "Failed to stop trace after multiple attempts."
            }
            return @{
                Success = $false
                Error = "netsh trace stop failed after $stopAttempts attempts. Last exit code: $($process.ExitCode)"
            }
        }
    }
    catch {
        Write-Error "Error stopping network trace: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
    finally {
        # Clean up script variables
        $script:IsTracing = $false
        $script:CurrentLogFile = $null

        # Clean up counter file
        if ($script:CounterFile -and (Test-Path $script:CounterFile)) {
            Remove-Item $script:CounterFile -Force -ErrorAction SilentlyContinue
        }
        $script:CounterFile = $null

        # Clean up background job
        if ($script:TraceJob) {
            # Give the job a moment to see the flag file removal and stop gracefully
            Start-Sleep -Milliseconds 500

            if ($script:TraceJob.State -eq 'Running') {
                Stop-Job -Job $script:TraceJob -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $script:TraceJob -Force -ErrorAction SilentlyContinue
            $script:TraceJob = $null
        }

        if ($script:MonitorFlag) {
            $script:MonitorFlag.Set()
            $script:MonitorFlag.Dispose()
            $script:MonitorFlag = $null
        }
    }
}

<#
.SYNOPSIS
    Gets the current status of NetTrace operations

.DESCRIPTION
    Provides a quick status check for both job-based and service-based NetTrace operations.
    This command works without requiring the -Log parameter and shows current trace status,
    file counts, and configuration information.

.EXAMPLE
    Get-NetTraceStatus

    Shows current NetTrace status including running mode, file counts, and configuration.

.EXAMPLE
    $status = Get-NetTraceStatus
    if ($status.IsRunning) {
        Write-Host "NetTrace is running with $($status.FilesCreated) files created"
    }

    Programmatically check NetTrace status and access status properties.
#>
function Get-NetTraceStatus {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param()

    try {
        # Check for administrator privileges
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$currentUser
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-Warning "Administrator privileges required for complete status information."
        }

        # Initialize status object
        $status = @{
            IsRunning = $false
            FilesCreated = 0
            FilesRolled = 0
            CurrentFile = ""
            LastUpdate = ""
            ErrorMessage = ""
            Mode = "None"
            Path = ""
            MaxFiles = 0
            MaxSizeMB = 0
            Persistence = $false
            LoggingEnabled = $false
        }

        # Check Windows Service persistence first
        $serviceRunning = $false
        try {
            $moduleDir = $PSScriptRoot
            if (-not $moduleDir) {
                $moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
            }

            # Check if Windows Service is running
            $windowsService = Get-Service -Name "NetTraceService" -ErrorAction SilentlyContinue
            if ($windowsService -and $windowsService.Status -eq 'Running') {
                $serviceRunning = $true
                $status.IsRunning = $true
                $status.Mode = "WindowsService"
                $status.Persistence = $true

                # Get detailed status from Windows Service
                $serviceStatus = Get-WindowsServiceStatus
                $status.FilesCreated = $serviceStatus.FilesCreated
                $status.FilesRolled = $serviceStatus.FilesRolled
                $status.CurrentFile = $serviceStatus.CurrentFile
                $status.LastUpdate = $serviceStatus.LastUpdate
                $status.ErrorMessage = $serviceStatus.ErrorMessage

                # Get configuration from Windows Service
                $serviceScript = Join-Path $moduleDir "NetTrace-Service.ps1"
                if (Test-Path $serviceScript) {
                    . $serviceScript
                    $serviceConfig = Get-ServiceConfig
                    if ($serviceConfig) {
                        $status.Path = $serviceConfig.Path
                        $status.MaxFiles = $serviceConfig.MaxFiles
                        $status.MaxSizeMB = $serviceConfig.MaxSizeMB
                        $status.LoggingEnabled = $serviceConfig.EnableLogging
                    }
                }
            }
        } catch {
            # Service not available or error checking status
            $serviceRunning = $false
        }

        # Check job-based operation if service is not running
        if (-not $serviceRunning) {
            if ($script:IsTracing) {
                $status.IsRunning = $true
                $status.Mode = "Job"
                $status.Path = $script:TracePath
                $status.MaxFiles = $script:MaxFiles
                $status.MaxSizeMB = $script:MaxSizeMB
                $status.Persistence = $script:PersistenceEnabled
                $status.LoggingEnabled = $null -ne $script:CurrentLogFile

                # Get current counts from counter file
                $currentCounts = Get-CurrentCount
                $status.FilesCreated = $currentCounts.FilesCreated
                $status.FilesRolled = $currentCounts.FilesRolled
                $status.CurrentFile = $currentCounts.CurrentFile
                $status.LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }

        return $status
    }
    catch {
        Write-Error "Error retrieving NetTrace status: $($_.Exception.Message)"
        return @{
            IsRunning = $false
            FilesCreated = 0
            FilesRolled = 0
            CurrentFile = ""
            LastUpdate = ""
            ErrorMessage = $_.Exception.Message
            Mode = "Error"
            Path = ""
            MaxFiles = 0
            MaxSizeMB = 0
            Persistence = $false
            LoggingEnabled = $false
        }
    }
}

# Export the main functions
Export-ModuleMember -Function NetTrace, Get-NetTraceStatus
