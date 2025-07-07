# NetTrace Scheduled Task Setup
# Alternative approach using Windows Task Scheduler

#Requires -Version 5.1
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory)]
    [ValidateSet('Install', 'Uninstall', 'Start', 'Stop', 'Status')]
    [string]$Action,
    
    [string]$TaskName = 'NetTrace-Monitoring',
    [string]$Description = 'Continuous network traffic monitoring using NetTrace',
    
    # NetTrace parameters
    [string]$TracePath = 'C:\NetTrace\Scheduled',
    [int]$MaxFiles = 10,
    [int]$MaxSizeMB = 100,
    [switch]$EnableLogging
)

function Install-NetTraceTask {
    Write-Host "Installing NetTrace as Scheduled Task..." -ForegroundColor Green
    
    # Create the PowerShell script that will run NetTrace
    $scriptContent = @"
# NetTrace Scheduled Task Runner
Import-Module "$PSScriptRoot\NetTrace.psd1" -Force

# Create trace directory
if (-not (Test-Path "$TracePath")) {
    New-Item -Path "$TracePath" -ItemType Directory -Force | Out-Null
}

# Start NetTrace
try {
    if ($EnableLogging) {
        NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path "$TracePath" -Log -Verbose
    } else {
        NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path "$TracePath" -Verbose
    }
    
    # Keep running indefinitely
    while (`$true) {
        Start-Sleep -Seconds 30
    }
} catch {
    Write-Error "NetTrace task error: `$(`$_.Exception.Message)"
    # Log to event log
    Write-EventLog -LogName Application -Source "NetTrace Task" -EventID 1001 -EntryType Error -Message "NetTrace task error: `$(`$_.Exception.Message)" -ErrorAction SilentlyContinue
}
"@
    
    $scriptPath = "$PSScriptRoot\NetTrace-TaskRunner.ps1"
    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
    
    # Create event log source
    try {
        New-EventLog -LogName Application -Source "NetTrace Task" -ErrorAction SilentlyContinue
    } catch {
        # Source might already exist
    }
    
    # Create the scheduled task
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Days 365)
    
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description $Description
    
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force
    
    Write-Host "Scheduled task '$TaskName' created successfully!" -ForegroundColor Green
    Write-Host "Task will start automatically at system startup." -ForegroundColor Cyan
    Write-Host "Use 'Start-ScheduledTask $TaskName' to start it now." -ForegroundColor Cyan
}

function Uninstall-NetTraceTask {
    Write-Host "Uninstalling NetTrace scheduled task..." -ForegroundColor Yellow
    
    # Stop task if running
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Running') {
        Stop-ScheduledTask -TaskName $TaskName
        Write-Host "Task stopped." -ForegroundColor Yellow
    }
    
    # Remove task
    if ($task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Scheduled task '$TaskName' removed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Scheduled task '$TaskName' not found." -ForegroundColor Yellow
    }
    
    # Clean up runner script
    $scriptPath = "$PSScriptRoot\NetTrace-TaskRunner.ps1"
    if (Test-Path $scriptPath) {
        Remove-Item $scriptPath -Force
        Write-Host "Task runner script removed." -ForegroundColor Green
    }
}

function Get-NetTraceTaskStatus {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "Task Status: $($task.State)" -ForegroundColor Cyan
        Write-Host "Last Run Time: $($task.LastRunTime)" -ForegroundColor Cyan
        Write-Host "Next Run Time: $($task.NextRunTime)" -ForegroundColor Cyan
        Write-Host "Description: $($task.Description)" -ForegroundColor Cyan
    } else {
        Write-Host "Scheduled task '$TaskName' is not installed." -ForegroundColor Yellow
    }
}

# Main execution
switch ($Action) {
    'Install' {
        Install-NetTraceTask
    }
    'Uninstall' {
        Uninstall-NetTraceTask
    }
    'Start' {
        Start-ScheduledTask -TaskName $TaskName
        Write-Host "Scheduled task '$TaskName' started." -ForegroundColor Green
    }
    'Stop' {
        Stop-ScheduledTask -TaskName $TaskName
        Write-Host "Scheduled task '$TaskName' stopped." -ForegroundColor Yellow
    }
    'Status' {
        Get-NetTraceTaskStatus
    }
}

Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Cyan
Write-Host "  Install: .\NetTrace-ScheduledTask.ps1 -Action Install -TracePath 'C:\Traces' -MaxFiles 5 -MaxSizeMB 200" -ForegroundColor Gray
Write-Host "  Start:   .\NetTrace-ScheduledTask.ps1 -Action Start" -ForegroundColor Gray
Write-Host "  Status:  .\NetTrace-ScheduledTask.ps1 -Action Status" -ForegroundColor Gray
Write-Host "  Stop:    .\NetTrace-ScheduledTask.ps1 -Action Stop" -ForegroundColor Gray
Write-Host "  Remove:  .\NetTrace-ScheduledTask.ps1 -Action Uninstall" -ForegroundColor Gray 