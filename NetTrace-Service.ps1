# NetTrace Windows Service Wrapper
# This script helps install NetTrace as a Windows Service for persistent operation

#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory)]
    [ValidateSet('Install', 'Uninstall', 'Start', 'Stop', 'Status')]
    [string]$Action,
    
    [string]$ServiceName = 'NetTrace',
    [string]$DisplayName = 'NetTrace Network Monitoring Service',
    [string]$Description = 'Continuous network traffic monitoring using NetTrace PowerShell module',
    
    # NetTrace parameters
    [string]$TracePath = 'C:\NetTrace\Service',
    [int]$MaxFiles = 10,
    [int]$MaxSizeMB = 100,
    [switch]$EnableLogging
)

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-NetTraceService {
    Write-Host "Installing NetTrace as Windows Service..." -ForegroundColor Green
    
    # Create service directory
    $serviceDir = Split-Path $TracePath -Parent
    if (-not (Test-Path $serviceDir)) {
        New-Item -Path $serviceDir -ItemType Directory -Force | Out-Null
    }
    
    # Create the service runner script with proper service handling
    $runnerScript = @"
# NetTrace Service Runner
# This script runs NetTrace continuously as a Windows Service

param(
    [string]`$TracePath = '$TracePath',
    [int]`$MaxFiles = $MaxFiles,
    [int]`$MaxSizeMB = $MaxSizeMB,
    [switch]`$EnableLogging = `$$($EnableLogging.IsPresent)
)

# Set up error handling
`$ErrorActionPreference = 'Stop'
`$VerbosePreference = 'Continue'

# Import NetTrace module
try {
    Import-Module "$PSScriptRoot\NetTrace.psd1" -Force
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1000 -EntryType Information -Message "NetTrace module imported successfully"
} catch {
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1001 -EntryType Error -Message "Failed to import NetTrace module: `$(`$_.Exception.Message)"
    exit 1
}

# Create trace directory
if (-not (Test-Path `$TracePath)) {
    try {
        New-Item -Path `$TracePath -ItemType Directory -Force | Out-Null
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1002 -EntryType Information -Message "Created trace directory: `$TracePath"
    } catch {
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1003 -EntryType Error -Message "Failed to create trace directory: `$(`$_.Exception.Message)"
        exit 1
    }
}

# Start NetTrace
try {
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1004 -EntryType Information -Message "Starting NetTrace service with Path: `$TracePath, MaxFiles: `$MaxFiles, MaxSizeMB: `$MaxSizeMB, Logging: `$EnableLogging"
    
    if (`$EnableLogging) {
        `$result = NetTrace -File `$MaxFiles -FileSize `$MaxSizeMB -Path `$TracePath -Log
    } else {
        `$result = NetTrace -File `$MaxFiles -FileSize `$MaxSizeMB -Path `$TracePath
    }
    
    if (`$result.Success) {
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1005 -EntryType Information -Message "NetTrace started successfully. Files created: `$(`$result.FilesCreated)"
        
        # Service main loop - keep running and monitor
        while (`$true) {
            Start-Sleep -Seconds 30
            
            # Basic health check - verify trace is still running
            try {
                `$traceStatus = netsh trace show status 2>`$null
                if (`$traceStatus -like "*not running*") {
                    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1006 -EntryType Warning -Message "NetTrace appears to have stopped, attempting restart..."
                    
                    # Try to restart
                    if (`$EnableLogging) {
                        `$result = NetTrace -File `$MaxFiles -FileSize `$MaxSizeMB -Path `$TracePath -Log
                    } else {
                        `$result = NetTrace -File `$MaxFiles -FileSize `$MaxSizeMB -Path `$TracePath
                    }
                    
                    if (`$result.Success) {
                        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1007 -EntryType Information -Message "NetTrace restarted successfully"
                    }
                }
            } catch {
                # Health check failed, log but continue
                Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1008 -EntryType Warning -Message "Health check failed: `$(`$_.Exception.Message)"
            }
        }
    } else {
        Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1009 -EntryType Error -Message "NetTrace failed to start"
        exit 1
    }
} catch {
    Write-EventLog -LogName Application -Source "NetTrace Service" -EventID 1010 -EntryType Error -Message "NetTrace service error: `$(`$_.Exception.Message)"
    exit 1
}
"@
    
    $runnerPath = "$PSScriptRoot\NetTrace-ServiceRunner.ps1"
    $runnerScript | Out-File -FilePath $runnerPath -Encoding UTF8
    
    # Create event log source
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("NetTrace Service")) {
            New-EventLog -LogName Application -Source "NetTrace Service"
        }
    } catch {
        Write-Warning "Could not create event log source: $($_.Exception.Message)"
    }
    
    # Use sc.exe to create the service with proper parameters
    $servicePath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $serviceArgs = "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""
    
    # Create the service
    $scResult = & sc.exe create $ServiceName binPath= "`"$servicePath`" $serviceArgs" DisplayName= "$DisplayName" start= auto
    
    if ($LASTEXITCODE -eq 0) {
        # Set service description
        & sc.exe description $ServiceName "$Description"
        
        # Configure service recovery options
        & sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000
        
        Write-Host "Service '$ServiceName' installed successfully!" -ForegroundColor Green
        Write-Host "Service will start automatically on system boot." -ForegroundColor Cyan
        Write-Host "Use 'Start-Service $ServiceName' to start it now." -ForegroundColor Cyan
        
        # Show service info
        Get-Service -Name $ServiceName | Format-Table Name, Status, StartType, DisplayName -AutoSize
    } else {
        Write-Error "Failed to create service. Exit code: $LASTEXITCODE"
        Write-Host "Output: $scResult" -ForegroundColor Red
    }
}

function Uninstall-NetTraceService {
    Write-Host "Uninstalling NetTrace service..." -ForegroundColor Yellow
    
    # Stop service if running
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') {
        try {
            # Stop NetTrace first
            Import-Module "$PSScriptRoot\NetTrace.psd1" -Force -ErrorAction SilentlyContinue
            NetTrace -Stop -ErrorAction SilentlyContinue
            
            Stop-Service -Name $ServiceName -Force -TimeoutSec 30
            Write-Host "Service stopped." -ForegroundColor Yellow
        } catch {
            Write-Warning "Error stopping service: $($_.Exception.Message)"
        }
    }
    
    # Remove service using sc.exe
    if ($service) {
        $scResult = & sc.exe delete $ServiceName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Service '$ServiceName' removed successfully!" -ForegroundColor Green
        } else {
            Write-Error "Failed to remove service. Exit code: $LASTEXITCODE"
        }
    } else {
        Write-Host "Service '$ServiceName' not found." -ForegroundColor Yellow
    }
    
    # Clean up runner script
    $runnerPath = "$PSScriptRoot\NetTrace-ServiceRunner.ps1"
    if (Test-Path $runnerPath) {
        Remove-Item $runnerPath -Force
        Write-Host "Service runner script removed." -ForegroundColor Green
    }
}

function Start-NetTraceService {
    try {
        Start-Service -Name $ServiceName
        Write-Host "Service '$ServiceName' started." -ForegroundColor Green
        
        # Wait a moment and check status
        Start-Sleep -Seconds 3
        $service = Get-Service -Name $ServiceName
        if ($service.Status -eq 'Running') {
            Write-Host "Service is running successfully." -ForegroundColor Green
        } else {
            Write-Warning "Service status: $($service.Status)"
        }
    } catch {
        Write-Error "Failed to start service: $($_.Exception.Message)"
        Write-Host "Check Windows Event Log for details:" -ForegroundColor Yellow
        Write-Host "  Get-EventLog -LogName Application -Source 'NetTrace Service' -Newest 5" -ForegroundColor Gray
    }
}

function Stop-NetTraceService {
    try {
        # Stop NetTrace first
        Import-Module "$PSScriptRoot\NetTrace.psd1" -Force -ErrorAction SilentlyContinue
        NetTrace -Stop -ErrorAction SilentlyContinue
        
        Stop-Service -Name $ServiceName -Force
        Write-Host "Service '$ServiceName' stopped." -ForegroundColor Yellow
    } catch {
        Write-Error "Failed to stop service: $($_.Exception.Message)"
    }
}

function Get-NetTraceServiceStatus {
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "Service Status Information:" -ForegroundColor Cyan
        $service | Format-Table Name, Status, StartType, DisplayName -AutoSize
        
        # Show recent events
        Write-Host "Recent Service Events:" -ForegroundColor Cyan
        try {
            Get-EventLog -LogName Application -Source "NetTrace Service" -Newest 5 -ErrorAction SilentlyContinue | 
                Format-Table TimeGenerated, EntryType, EventID, Message -Wrap
        } catch {
            Write-Host "No recent events found." -ForegroundColor Gray
        }
    } else {
        Write-Host "Service '$ServiceName' is not installed." -ForegroundColor Yellow
    }
}

# Validate admin privileges
if (-not (Test-AdminPrivileges)) {
    Write-Error "This script requires administrator privileges. Please run as administrator."
    exit 1
}

# Main execution
switch ($Action) {
    'Install' {
        Install-NetTraceService
    }
    'Uninstall' {
        Uninstall-NetTraceService
    }
    'Start' {
        Start-NetTraceService
    }
    'Stop' {
        Stop-NetTraceService
    }
    'Status' {
        Get-NetTraceServiceStatus
    }
}

Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Cyan
Write-Host "  Install: .\NetTrace-Service.ps1 -Action Install -TracePath 'C:\Traces' -MaxFiles 5 -MaxSizeMB 200" -ForegroundColor Gray
Write-Host "  Start:   .\NetTrace-Service.ps1 -Action Start" -ForegroundColor Gray
Write-Host "  Status:  .\NetTrace-Service.ps1 -Action Status" -ForegroundColor Gray
Write-Host "  Stop:    .\NetTrace-Service.ps1 -Action Stop" -ForegroundColor Gray
Write-Host "  Remove:  .\NetTrace-Service.ps1 -Action Uninstall" -ForegroundColor Gray 