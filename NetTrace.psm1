#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    NetTrace PowerShell Module for Windows Network Tracing
    
.DESCRIPTION
    A PowerShell module that provides functionality to perform network traces using Windows native Netsh utility.
    Creates multiple trace files with automatic rotation based on file size limits.
    
.NOTES
    File Name      : NetTrace.psm1
    Author         : NetTrace Module
    Prerequisite   : Windows 10/11 with Netsh utility
    Requires       : Administrator privileges
    Compatibility  : PowerShell 5.1 and PowerShell 7+
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
    
.PARAMETER Verbose
    Shows detailed information about files created, rolled, and deleted during circular management.
    
.EXAMPLE
    NetTrace -File 2 -FileSize 10 -Path "C:\Traces"
    Creates up to 2 files of 10MB each. When the 3rd file is needed, deletes the 1st file.
    
.EXAMPLE
    NetTrace -File 5 -FileSize 50 -Path "C:\Traces" -Verbose
    Maintains 5 files of 50MB each with detailed output showing file management.
    
.EXAMPLE
    NetTrace -File 2 -FileSize 10 -Path "C:\Traces" -LogNetshOutput
    Same as first example but logs all netsh output to C:\Traces\netsh_trace.log
    
.EXAMPLE
    NetTrace -Stop
    Stops the currently running trace.
#>
function NetTrace {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$File,
        
        [Parameter()]
        [int]$FileSize,
        
        [Parameter()]
        [string]$Path,
        
        [Parameter()]
        [switch]$Stop,
        
        [Parameter()]
        [switch]$LogNetshOutput
    )
    
    try {
        # Handle stop command
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
        
        # Start trace capture
        Start-NetTraceCapture -Path $Path -MaxFiles $File -MaxSizeMB $FileSize -LogOutput:$LogNetshOutput
    }
    catch {
        Write-Error "Error in NetTrace: $($_.Exception.Message)"
        throw
    }
}

function Start-NetTraceCapture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [int]$MaxFiles,
        
        [Parameter(Mandatory)]
        [int]$MaxSizeMB,
        
        [Parameter()]
        [bool]$LogOutput = $false
    )
    
    try {
        $script:TracePath = $Path
        $script:MaxFiles = $MaxFiles
        $script:MaxSizeMB = $MaxSizeMB
        $script:FilesCreated = 0
        $script:FilesRolled = 0
        
        if ($VerbosePreference -eq 'Continue') {
            Write-Host "Starting network trace..." -ForegroundColor Green
            Write-Host "Path: $Path" -ForegroundColor Yellow
            Write-Host "Max Files: $MaxFiles" -ForegroundColor Yellow
            Write-Host "Max Size: $MaxSizeMB MB" -ForegroundColor Yellow
        }
        
        # Force stop any existing netsh trace to ensure clean start
        & netsh trace stop 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        
        # Get computer name and calculate max size in bytes
        $computerName = $env:COMPUTERNAME
        $maxSizeBytes = $MaxSizeMB * 1MB
        
        # Create monitoring flag for stop functionality
        $script:MonitorFlag = [System.Threading.ManualResetEvent]::new($false)
        $script:IsTracing = $true
        
        # Show initial message
        if ($VerbosePreference -eq 'Continue') {
            Write-Host "Network trace started successfully with circular file management." -ForegroundColor Green
            Write-Host "Will maintain $MaxFiles files of $MaxSizeMB MB each, replacing oldest when full." -ForegroundColor Cyan
            Write-Host "Use 'NetTrace -Stop' to stop." -ForegroundColor Cyan
        }
        
        # Start background job for file monitoring
        $script:TraceJob = Start-Job -ScriptBlock {
            param($TracePath, $MaxFiles, $MaxSizeMB, $LogOutput, $LogFile)
            
            $fileNumber = 1
            $filesCreated = 0
            $filesRolled = 0
            $fileHistory = @()  # Track created files for circular management
            $computerName = $env:COMPUTERNAME
            $maxSizeBytes = $MaxSizeMB * 1MB
            
            # Create flag file to check if we should continue
            $flagFile = Join-Path $TracePath ".nettrace_running"
            "running" | Out-File -FilePath $flagFile -Force
            
            # Create files continuously with circular management
            while (Test-Path $flagFile) {
                # Generate filename with computer name and timestamp
                $dateStamp = Get-Date -Format "dd-MM-yy"
                $timeStamp = Get-Date -Format "HHmmss"
                $traceFile = Join-Path $TracePath "$computerName`_$dateStamp-$timeStamp.etl"
                $fileName = [System.IO.Path]::GetFileName($traceFile)
                
                # Log file creation
                "$(Get-Date -Format 'HH:mm:ss') - Creating File #$fileNumber : $fileName" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                
                # Start netsh trace with report disabled and no additional data capture
                $arguments = @("trace", "start", "capture=yes", "report=disabled", "overwrite=yes", "maxSize=$MaxSizeMB", "tracefile=`"$traceFile`"")
                
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
                "$(Get-Date -Format 'HH:mm:ss') - Netsh trace started for: $fileName" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                
                if ($process.ExitCode -ne 0) {
                    "$(Get-Date -Format 'HH:mm:ss') - ERROR: Failed to start trace. Exit code: $($process.ExitCode)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                    break
                }
                
                $filesCreated++
                
                # Add current file to history
                $fileHistory += @{
                    Number = $fileNumber
                    Path = $traceFile
                    Name = $fileName
                }
                
                "$(Get-Date -Format 'HH:mm:ss') - Monitoring file size (limit: $MaxSizeMB MB)..." | Out-File -FilePath $LogFile -Append -Encoding UTF8
                
                # Monitor this specific file until it reaches size limit
                $fileRotated = $false
                
                while (-not $fileRotated -and (Test-Path $flagFile)) {
                    # Use shorter sleep for better responsiveness and accuracy
                    Start-Sleep -Milliseconds 500
                    
                    if (Test-Path $traceFile) {
                        $fileSize = (Get-Item $traceFile).Length
                        
                        $sizeMB = [math]::Round($fileSize/1MB, 2)
                        "$(Get-Date -Format 'HH:mm:ss') - File: $fileName - Size: $sizeMB MB / $MaxSizeMB MB" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                        
                        if ($fileSize -ge $maxSizeBytes) {
                            # Size limit reached, rotate to next file
                            "$(Get-Date -Format 'HH:mm:ss') - Size limit reached! Rolling to new file..." | Out-File -FilePath $LogFile -Append -Encoding UTF8
                            
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
                                "$(Get-Date -Format 'HH:mm:ss') - Trace stopped for file: $fileName" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                            
                            if ($stopProcess.ExitCode -eq 0) {
                                $filesRolled++
                                $fileRotated = $true
                                $fileNumber++
                                
                                # Circular file management: remove oldest file if we exceed MaxFiles
                                if ($fileHistory.Count -gt $MaxFiles) {
                                    $oldestFile = $fileHistory[0]
                                    if (Test-Path $oldestFile.Path) {
                                        Remove-Item $oldestFile.Path -Force -ErrorAction SilentlyContinue
                                        "$(Get-Date -Format 'HH:mm:ss') - Removed oldest file: $($oldestFile.Name)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                                    }
                                    # Remove from history
                                    $fileHistory = $fileHistory[1..($fileHistory.Count-1)]
                                }
                            } else {
                                "$(Get-Date -Format 'HH:mm:ss') - ERROR: Failed to stop trace. Exit code: $($stopProcess.ExitCode)" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                                break
                            }
                        }
                    } else {
                        "$(Get-Date -Format 'HH:mm:ss') - ERROR: Trace file not found: $traceFile" | Out-File -FilePath $LogFile -Append -Encoding UTF8
                        break
                    }
                }
            }
            
            # Stop trace when manually stopped
            & netsh trace stop 2>&1 | Out-Null
            
            # Output summary to log
            "$(Get-Date -Format 'HH:mm:ss') - Trace session ended" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            "$(Get-Date -Format 'HH:mm:ss') - SUMMARY: Files created: $filesCreated, Files rolled: $filesRolled" | Out-File -FilePath $LogFile -Append -Encoding UTF8
            "=" * 60 | Out-File -FilePath $LogFile -Append -Encoding UTF8
            
        } -ArgumentList $Path, $MaxFiles, $MaxSizeMB, $LogOutput, $script:CurrentLogFile
        
        # Create log file for all output
        $script:CurrentLogFile = Join-Path $Path "NetTrace_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').log"
        "NetTrace session started at $(Get-Date)" | Out-File -FilePath $script:CurrentLogFile -Encoding UTF8
        "Command: NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path '$Path'" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
        "=" * 60 | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
        "" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
        
        Write-Host "Trace monitoring started in background." -ForegroundColor Green
        Write-Host "All output is being logged to: $($script:CurrentLogFile)" -ForegroundColor Cyan
        Write-Host "Use 'NetTrace -Stop' to stop the trace." -ForegroundColor Yellow
        Write-Host "You can monitor progress with: Get-Content '$($script:CurrentLogFile)' -Wait" -ForegroundColor Gray
        
        $script:TraceJob = $null
        
        # Return summary information
        return @{
            FilesCreated = $script:FilesCreated
            FilesRolled = $script:FilesRolled
            Success = $true
        }
    }
    catch {
        Write-Error "Error starting network trace: $($_.Exception.Message)"
        throw
    }
}

function Stop-NetTraceCapture {
    [CmdletBinding()]
    param()
    
    try {
        if ($VerbosePreference -eq 'Continue') {
            Write-Host "Stopping network trace..." -ForegroundColor Yellow
        }
        
        # Set the flag to stop monitoring
        $script:IsTracing = $false
        
        # Remove flag file to stop background job
        if ($script:TracePath) {
            $flagFile = Join-Path $script:TracePath ".nettrace_running"
            Remove-Item $flagFile -Force -ErrorAction SilentlyContinue
        }
        
        # Stop netsh trace
        & netsh trace stop 2>&1 | Out-Null
        $process = [PSCustomObject]@{ ExitCode = $LASTEXITCODE }
        
        if ($process.ExitCode -eq 0) {
            Write-Host "Trace stopped." -ForegroundColor Green
            
            # Log the stop action
            if ($script:CurrentLogFile -and (Test-Path $script:CurrentLogFile)) {
                "$(Get-Date -Format 'HH:mm:ss') - Manual stop command received" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
                "$(Get-Date -Format 'HH:mm:ss') - NetTrace session ended by user" | Out-File -FilePath $script:CurrentLogFile -Append -Encoding UTF8
                Write-Host "Final logs saved to: $($script:CurrentLogFile)" -ForegroundColor Cyan
            }
            
            return @{
                Success = $true
                FilesCreated = $script:FilesCreated
                FilesRolled = $script:FilesRolled
            }
        } else {
            if ($VerbosePreference -eq 'Continue') {
                Write-Host "Failed to stop trace. Exit code: $($process.ExitCode)" -ForegroundColor Red
            } else {
                Write-Host "Failed to stop trace."
            }
            return @{
                Success = $false
                Error = "netsh trace stop failed with exit code $($process.ExitCode)"
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
        
        # Clean up background job
        if ($script:TraceJob) {
            Stop-Job -Job $script:TraceJob -ErrorAction SilentlyContinue
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

# Export the main function
Export-ModuleMember -Function NetTrace 
