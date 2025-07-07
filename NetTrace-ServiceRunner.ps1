# NetTrace Service Runner
# This script runs NetTrace continuously as a Windows Service

param(
    [string]$TracePath = 'C:\NetTrace\Service',
    [int]$MaxFiles = 20,
    [int]$MaxSizeMB = 500,
    [switch]$EnableLogging = $True
)

# Set up error handling
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Import NetTrace module
try {
    Import-Module "E:\Cursor\PowerShell Modules\NetTrace\NetTrace.psd1" -Force
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1000 -EntryType Information -Message "NetTrace module imported successfully"
} catch {
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1001 -EntryType Error -Message "Failed to import NetTrace module: $($_.Exception.Message)"
    exit 1
}

# Create trace directory
if (-not (Test-Path $TracePath)) {
    try {
        New-Item -Path $TracePath -ItemType Directory -Force | Out-Null
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1002 -EntryType Information -Message "Created trace directory: $TracePath"
    } catch {
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1003 -EntryType Error -Message "Failed to create trace directory: $($_.Exception.Message)"
        exit 1
    }
}

# Start NetTrace
try {
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1004 -EntryType Information -Message "Starting NetTrace service with Path: $TracePath, MaxFiles: $MaxFiles, MaxSizeMB: $MaxSizeMB, Logging: $EnableLogging"
    
    if ($EnableLogging) {
        $result = NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path $TracePath -Log
    } else {
        $result = NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path $TracePath
    }
    
    if ($result.Success) {
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1005 -EntryType Information -Message "NetTrace started successfully. Files created: $($result.FilesCreated)"
        
        # Service main loop - keep running and monitor
        while ($true) {
            Start-Sleep -Seconds 30
            
            # Basic health check - verify trace is still running
            try {
                $traceStatus = netsh trace show status 2>$null
                if ($traceStatus -like "*not running*") {
                    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1006 -EntryType Warning -Message "NetTrace appears to have stopped, attempting restart..."
                    
                    # Try to restart
                    if ($EnableLogging) {
                        $result = NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path $TracePath -Log
                    } else {
                        $result = NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path $TracePath
                    }
                    
                    if ($result.Success) {
                        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1007 -EntryType Information -Message "NetTrace restarted successfully"
                    }
                }
            } catch {
                # Health check failed, log but continue
                Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1008 -EntryType Warning -Message "Health check failed: $($_.Exception.Message)"
            }
        }
    } else {
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1009 -EntryType Error -Message "NetTrace failed to start"
        exit 1
    }
} catch {
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1010 -EntryType Error -Message "NetTrace service error: $($_.Exception.Message)"
    exit 1
}
