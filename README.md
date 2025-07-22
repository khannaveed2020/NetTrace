# NetTrace PowerShell Module

A professional PowerShell module for Windows network tracing using the native `netsh trace` utility with circular file management, non-blocking background operation, and enterprise-grade persistence capabilities.

## Synopsis

NetTrace solves the fundamental limitations of native `netsh trace` by providing a professional, production-ready network tracing solution. While `netsh trace` is powerful, it has significant drawbacks for enterprise use:

- **Blocking operation** - Console locks up during capture
- **Manual file management** - No automatic rotation or cleanup
- **No persistence** - Stops when user logs out or system reboots
- **Poor user experience** - Requires CTRL+C to stop, no progress visibility
- **Limited logging** - No activity tracking or troubleshooting data

NetTrace transforms `netsh trace` into an enterprise-grade tool with automatic file rotation, background operation, comprehensive logging, and true persistence that survives user sessions and system reboots.

## Use Case & Problem Solved

### The Native NetSh Trace Problem

Native `netsh trace` has these limitations:

```powershell
# Native netsh trace - BLOCKS console, manual file management
netsh trace start capture=yes tracefile=C:\traces\trace.etl maxsize=100

# Console is now locked until you press CTRL+C
# No automatic file rotation
# No persistence across sessions
# No activity logging
# No progress visibility
```

### NetTrace Solution

NetTrace provides a complete enterprise solution:

```powershell
# NetTrace - Non-blocking, automatic rotation, persistence
NetTrace -File 5 -FileSize 100 -Path "C:\NetworkTraces" -Persistence $true -Log

# Console immediately available for other work
# Automatic file rotation (keeps 5 files, 100MB each)
# Survives user logout and system reboot
# Comprehensive activity logging
# Real-time progress monitoring
```

## Installation

### From PowerShell Gallery (Recommended)

```powershell
Install-Module -Name NetTrace
```

### Manual Installation

1. Download or clone the module files
2. Place them in a directory accessible to PowerShell
3. Import the module:

```powershell
Import-Module .\NetTrace.psd1
```

## Important: Administrator Privileges Required

⚠️ **This module requires Administrator privileges to function.** 

The module will load successfully in non-admin PowerShell sessions, but when you try to run the `NetTrace` command, you'll receive an error message:

```
This module requires Administrator privileges. Please run PowerShell as Administrator.
```

**To use this module:**
1. Right-click on PowerShell and select "Run as Administrator"
2. Or use `Start-Process PowerShell -Verb RunAs`

## Basic File Rotation Instructions

### Core Concept

NetTrace implements intelligent circular file management:

1. **Creates files sequentially** until reaching the specified count
2. **When creating a new file**, automatically deletes the oldest file
3. **Maintains exact file count** and size limits
4. **Runs continuously** until manually stopped

### Basic Usage Examples

#### Simple File Rotation (2 files, 50MB each)
```powershell
NetTrace -File 2 -FileSize 50 -Path "C:\NetworkTraces"
```

**Expected file sequence:**
```
File #1: ServerName_22-01-25-140530.etl (50MB) - Created
File #2: ServerName_22-01-25-142545.etl (50MB) - Created  
File #3: ServerName_22-01-25-144601.etl (50MB) - Created, File #1 deleted
File #4: ServerName_22-01-25-150616.etl (50MB) - Created, File #2 deleted
```

#### Enterprise Rotation (10 files, 100MB each)
```powershell
NetTrace -File 10 -FileSize 100 -Path "D:\NetworkLogs\Production" -Log
```

**Benefits:**
- **1GB total storage** (10 × 100MB)
- **Automatic cleanup** - No manual file management
- **Continuous capture** - No gaps in network data
- **Predictable storage** - Never exceeds configured limits

### File Rotation Commands

#### Check Current Files
```powershell
# List all trace files with details
Get-ChildItem "C:\NetworkTraces" -Filter "*.etl" | 
    Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}}, LastWriteTime

# Count files and total size
$files = Get-ChildItem "C:\NetworkTraces" -Filter "*.etl"
$totalSize = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
Write-Host "Files: $($files.Count) | Total Size: ${totalSize}MB"
```

#### Monitor File Rotation in Real-Time
```powershell
# Watch files being created and rotated
while ($true) {
    $files = Get-ChildItem "C:\NetworkTraces" -Filter "*.etl"
    $totalSize = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Files: $($files.Count) | Total: ${totalSize}MB"
    Start-Sleep -Seconds 10
}
```

#### Check Rotation Activity
```powershell
# View rotation events in activity logs
Get-Content "C:\NetworkTraces\NetTrace_*.log" | Where-Object { $_ -match "Removed oldest file" }
```

## Persistence Capture Instructions

### Overview

NetTrace's persistence feature provides **true enterprise-grade persistence** that survives:
- ✅ **User session termination** (RDP disconnect, logout)
- ✅ **System reboots** (maintenance, updates)
- ✅ **Service restarts** (Windows service management)
- ✅ **Cross-user sessions** (monitor from any user account)

### Persistence vs Basic NetSh

| Feature | Native NetSh | NetTrace Persistence |
|---------|-------------|---------------------|
| Survives reboot | ❌ | ✅ |
| Survives user logout | ❌ | ✅ |
| File rotation continues | ❌ | ✅ |
| Cross-session monitoring | ❌ | ✅ |
| Automatic service management | ❌ | ✅ |

### Persistence Examples

#### Basic Persistence Setup
```powershell
# Start persistent capture (survives logout & reboot)
NetTrace -File 3 -FileSize 50 -Path "C:\NetworkTraces" -Persistence $true -Log

# Expected output:
# Starting Windows Service persistent network trace...
# Path: C:\NetworkTraces
# Max Files: 3
# Max Size: 50 MB
# True Windows Service persistence: Enabled
# Windows Service persistent trace started successfully.
```

#### Enterprise Persistence Deployment
```powershell
# Production server monitoring
NetTrace -File 10 -FileSize 100 -Path "D:\NetworkLogs\Production" -Persistence $true -Log -Verbose

# Service continues running even after:
# - Administrator logout
# - RDP session disconnect  
# - System maintenance reboot
# - User account changes
```

#### Multi-User Session Testing
```powershell
# User 1: Start persistent trace
NetTrace -File 3 -FileSize 20 -Path "C:\SharedTraces" -Persistence $true -Log

# User 1: Logout or disconnect RDP session

# User 2: Monitor from different session  
Get-Service NetTraceService | Select-Object Name, Status, StartType
nssm status NetTraceService
Get-ChildItem "C:\SharedTraces" | Select-Object Name, Length, LastWriteTime

# User 2: Continuous monitoring
while ($true) {
    $files = Get-ChildItem "C:\SharedTraces" -Filter "*.etl"
    $totalSize = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Service: $(Get-Service NetTraceService -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status) | Files: $($files.Count) | Total: ${totalSize}MB"
    Start-Sleep -Seconds 10
}

# User 1: Reconnect and stop
NetTrace -Stop
```

## Monitoring the Trace

### Service Status Monitoring

#### Quick Service Status
```powershell
# Basic service status
Get-Service NetTraceService | Select-Object Name, Status, StartType

# NSSM detailed status
nssm status NetTraceService

# Combined status check
Get-Service NetTraceService; nssm status NetTraceService
```

#### NetTrace Built-in Status
```powershell
# Comprehensive status from NetTrace
Get-NetTraceStatus

# Expected output:
# IsRunning     : True
# FilesCreated  : 3
# FilesRolled   : 2
# Mode          : WindowsService
# Path          : C:\NetworkTraces
# MaxFiles      : 5
# MaxSizeMB     : 50
# Persistence   : True
# LoggingEnabled: True
# LastUpdate    : 2025-01-22 14:45:30
```

### File System Monitoring

#### Real-Time File Monitoring
```powershell
# Monitor trace files being created
Get-ChildItem "C:\NetworkTraces" | Select-Object Name, Length, LastWriteTime

# Monitor file sizes and count
$files = Get-ChildItem "C:\NetworkTraces" -Filter "*.etl"
$totalSize = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
Write-Host "Files: $($files.Count) | Total Size: ${totalSize}MB"

# Show newest file details
Get-ChildItem "C:\NetworkTraces" -Filter "*.etl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

#### Continuous File Monitoring Dashboard
```powershell
# Advanced monitoring dashboard
while ($true) {
    Clear-Host
    Write-Host "=== NetTrace Monitoring Dashboard ===" -ForegroundColor Green
    Write-Host "Time: $(Get-Date)" -ForegroundColor Cyan
    
    # Service status
    $service = Get-Service NetTraceService -ErrorAction SilentlyContinue
    $nssmStatus = & nssm status NetTraceService 2>$null
    Write-Host "Service Status: $($service.Status) | NSSM: $nssmStatus" -ForegroundColor Yellow
    
    # File analysis
    $files = Get-ChildItem "C:\NetworkTraces" -Filter "*.etl" -ErrorAction SilentlyContinue
    if ($files) {
        Write-Host "`nTrace Files:" -ForegroundColor White
        $files | Sort-Object LastWriteTime | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            $age = (Get-Date) - $_.LastWriteTime
            Write-Host "  $($_.Name) - ${sizeMB}MB (Age: $($age.TotalMinutes.ToString('F1'))min)" -ForegroundColor Gray
        }
        
        $totalSize = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
        Write-Host "`nSummary: $($files.Count) files, ${totalSize}MB total" -ForegroundColor Green
    } else {
        Write-Host "`nNo trace files found yet..." -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 15
}
```

### NSSM Service Monitoring

#### NSSM Configuration Verification
```powershell
# Check NSSM service configuration
nssm get NetTraceService Application
nssm get NetTraceService AppParameters
nssm get NetTraceService AppDirectory
nssm get NetTraceService Start
nssm get NetTraceService ObjectName
```

#### NSSM Service Control
```powershell
# Start service via NSSM
nssm start NetTraceService

# Stop service via NSSM
nssm stop NetTraceService

# Restart service via NSSM
nssm restart NetTraceService

# Check NSSM status
nssm status NetTraceService
```

### Log File Monitoring

#### Service Activity Logs
```powershell
# Monitor service internal logs
Get-Content "C:\ProgramData\NetTrace\service.log" -Tail 10

# Real-time service log monitoring
Get-Content "C:\ProgramData\NetTrace\service.log" -Wait -Tail 5

# Filter for errors only
Get-Content "C:\ProgramData\NetTrace\service.log" | Where-Object { $_ -match "ERROR" }
```

#### NetTrace Activity Logs
```powershell
# Monitor NetTrace activity logs (requires -Log parameter)
Get-Content "C:\NetworkTraces\NetTrace_*.log" -Tail 10

# Real-time activity monitoring
Get-Content "C:\NetworkTraces\NetTrace_*.log" -Wait -Tail 5

# Find the most recent log file
$latestLog = Get-ChildItem "C:\NetworkTraces" -Filter "NetTrace_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestLog) {
    Get-Content $latestLog.FullName -Tail 10
}
```

### Service Configuration Monitoring

#### Service Configuration Verification
```powershell
# Check current service configuration
Get-Content "C:\ProgramData\NetTrace\service_config.json" | ConvertFrom-Json | Format-List

# Expected output:
# Path          : C:\NetworkTraces
# MaxFiles      : 3
# MaxSizeMB     : 50
# LogOutput     : True
# EnableLogging : True
# StartTime     : 2025-01-22 14:45:30
# ServiceVersion: 1.3.6
```

#### Service Wrapper Verification
```powershell
# Check service wrapper batch file
Get-Content "C:\ProgramData\NetTrace\NetTrace-Service.bat"

# Expected content:
# @echo off
# REM NetTrace Service Wrapper
# cd /d "C:\Program Files\WindowsPowerShell\Modules\NetTrace\1.3.6"
# powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "C:\Program Files\WindowsPowerShell\Modules\NetTrace\1.3.6\NetTrace-Service.ps1" -ServiceMode
# exit /b %ERRORLEVEL%
```

### Advanced Monitoring Scripts

#### One-Liner Status Check
```powershell
Write-Host "Service: $(Get-Service NetTraceService -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status) | Files: $((Get-ChildItem 'C:\NetworkTraces' -Filter '*.etl' -ErrorAction SilentlyContinue).Count) | Size: $([math]::Round(((Get-ChildItem 'C:\NetworkTraces' -Filter '*.etl' -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB), 2))MB"
```

#### File Rotation Detection
```powershell
# Monitor for file rotation events
$initialCount = (Get-ChildItem "C:\NetworkTraces" -Filter "*.etl").Count
while ($true) {
    $currentCount = (Get-ChildItem "C:\NetworkTraces" -Filter "*.etl" -ErrorAction SilentlyContinue).Count
    if ($currentCount -ne $initialCount) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] File rotation detected! Files: $initialCount → $currentCount" -ForegroundColor Yellow
        $initialCount = $currentCount
    }
    Start-Sleep -Seconds 5
}
```

#### PowerShell Profile Integration
```powershell
# Add these functions to your PowerShell profile for easy access
function Watch-NetTrace {
    param([string]$Path = "C:\NetworkTraces")
    
    while ($true) {
        $service = Get-Service NetTraceService -ErrorAction SilentlyContinue
        $files = Get-ChildItem $Path -Filter "*.etl" -ErrorAction SilentlyContinue
        $totalSize = if ($files) { [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2) } else { 0 }
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Service: $($service.Status) | Files: $($files.Count) | Total: ${totalSize}MB" -ForegroundColor Green
        Start-Sleep -Seconds 10
    }
}

function Get-NetTraceFiles {
    param([string]$Path = "C:\NetworkTraces")
    Get-ChildItem $Path -Filter "*.etl" | Select-Object Name, @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}}, LastWriteTime
}
```

### Troubleshooting Monitoring

#### Service Not Starting
```powershell
# Check service logs for errors
Get-Content "C:\ProgramData\NetTrace\service.log" -Tail 20

# Check Windows Event Logs
Get-WinEvent -LogName System -MaxEvents 10 | Where-Object {$_.ProviderName -like "*NetTrace*"}

# Restart service
nssm restart NetTraceService
```

#### Service Shows Stopped But Files Still Growing
```powershell
# This is normal during service transitions
# Wait 30 seconds and check again
Start-Sleep -Seconds 30
Get-Service NetTraceService
nssm status NetTraceService
```

#### Cross-User Session Monitoring
```powershell
# From any user session, monitor service
Get-Service NetTraceService
nssm status NetTraceService

# Monitor files (works from any user since service runs as LocalSystem)
Get-ChildItem "C:\NetworkTraces" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

#### Service Configuration Issues
```powershell
# Check if parameters were saved correctly
Get-Content "C:\ProgramData\NetTrace\service_config.json" | ConvertFrom-Json | Format-List

# If config shows empty values, restart NetTrace command
NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true -Log
```

#### Clean Service Reset
```powershell
# Complete service cleanup and reinstall
nssm stop NetTraceService
nssm remove NetTraceService confirm
Remove-Item "C:\ProgramData\NetTrace" -Recurse -Force -ErrorAction SilentlyContinue

# Reinstall with fresh configuration
NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true -Log
```

## Quick Reference Commands

### Start Monitoring
```powershell
# Basic persistent trace
NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true -Log

# Monitor service status
Get-Service NetTraceService; nssm status NetTraceService

# Check trace files
Get-ChildItem "C:\NetworkTraces" | Select-Object Name, Length, LastWriteTime

# Stop persistent trace
NetTrace -Stop
```

### Monitoring Commands
```powershell
# Service status (from any user session)
Get-Service NetTraceService | Select-Object Name, Status, StartType
nssm status NetTraceService

# Service configuration
Get-Content "C:\ProgramData\NetTrace\service_config.json" | ConvertFrom-Json

# Service logs  
Get-Content "C:\ProgramData\NetTrace\service.log" -Tail 10

# Trace activity logs
Get-Content "C:\NetworkTraces\NetTrace_*.log" -Tail 10

# Real-time file monitoring
while ($true) {
    $files = Get-ChildItem "C:\NetworkTraces" -Filter "*.etl"
    $totalSize = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1MB, 2)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Files: $($files.Count) | Total: ${totalSize}MB"
    Start-Sleep -Seconds 10
}
```

## Version History

- **v1.3.6**: Enhanced Documentation
  - **Comprehensive Monitoring Guide**: Complete monitoring section with real-time dashboards
  - **Restructured Documentation**: Logical flow from synopsis through installation, usage, and monitoring
  - **Advanced Monitoring Scripts**: PowerShell profile integration and troubleshooting procedures
  - **Cross-Session Monitoring**: Multi-user session testing and enterprise deployment examples
- **v1.3.5**: Production-Ready Persistence with Enhanced Reliability
  - **CRITICAL FIX**: Resolved parameter scoping issue where dot-sourcing NetTrace-ServiceRunner.ps1 overwrote function parameters
  - **Enhanced Service State Management**: Robust NSSM service state checking with automatic recovery from PAUSED states
  - **Comprehensive Parameter Validation**: Added validation to prevent empty configuration values that caused service failures
  - **Race Condition Handling**: Prevents "already running" errors and service conflicts during start/stop operations
  - **Cross-User Session Support**: Service monitoring and control works from any user session
  - **Detailed Error Diagnostics**: Enhanced error reporting with service log analysis and recovery suggestions
  - **One-Command Reliability**: Single command operation now works without manual intervention or service state conflicts

## Requirements

- **Windows 10/11** with netsh utility
- **PowerShell 5.1** or PowerShell 7+
- **Administrator privileges** (required for network tracing)

## Files in This Module

| File | Purpose |
|------|---------|
| `NetTrace.psm1` | Main module functionality with dual-mode operation support |
| `NetTrace.psd1` | Module manifest |
| `NetTrace-Service.ps1` | Windows Service implementation for true persistent operation |
| `NetTrace-ServiceRunner.ps1` | Service installation and management script |
| `README.md` | Complete documentation (this file) |
| `LICENSE` | MIT license file |

## License

This module is provided as-is for educational and administrative purposes. 