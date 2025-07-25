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

## Why NetTrace vs Native NetSh Trace

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

### Feature Comparison

| Feature | Native NetSh | NetTrace |
|---------|-------------|----------|
| **Console Operation** | Blocks console | Non-blocking background |
| **File Management** | Manual rotation | Automatic circular rotation |
| **Persistence** | Stops on logout/reboot | True Windows Service persistence |
| **Logging** | No activity logs | Comprehensive logging |
| **Progress Visibility** | None | Real-time monitoring |
| **Enterprise Ready** | ❌ | ✅ |

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

## Quick Start Guide

### Basic Network Tracing

```powershell
# Start a simple network trace
NetTrace -File 3 -FileSize 50 -Path "C:\NetworkTraces"

# Check status
Get-NetTraceStatus

# Stop the trace
NetTrace -Stop
```

### Persistent Network Tracing (Enterprise)

```powershell
# Start persistent trace that survives reboots
NetTrace -File 5 -FileSize 100 -Path "C:\NetworkTraces" -Persistence $true -Log

# Monitor from any user session
Get-Service NetTraceService
Get-NetTraceStatus

# Stop persistent trace
NetTrace -Stop
```

## Basic Usage

### Core Concept

NetTrace implements intelligent circular file management:

1. **Creates files sequentially** until reaching the specified count
2. **When creating a new file**, automatically deletes the oldest file
3. **Maintains exact file count** and size limits
4. **Runs continuously** until manually stopped

### Basic Examples

#### Simple File Rotation (2 files, 50MB each)
```powershell
NetTrace -File 2 -FileSize 50 -Path "C:\Traces"
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

### File Management Commands

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

## Advanced Features

### Persistence Mode (-Persistence)

NetTrace's persistence feature provides **true enterprise-grade persistence** that survives:
- ✅ **User session termination** (RDP disconnect, logout)
- ✅ **System reboots** (maintenance, updates)
- ✅ **Service restarts** (Windows service management)
- ✅ **Cross-user sessions** (monitor from any user account)

#### NSSM Installation

Persistence mode requires NSSM (Non-Sucking Service Manager), which is automatically downloaded and installed:

```powershell
# NetTrace automatically downloads and installs NSSM
NetTrace -File 3 -FileSize 50 -Path "C:\NetworkTraces" -Persistence $true

# NSSM is installed to: C:\ProgramData\NetTrace\NSSM\nssm.exe
```

**Common NSSM Issues and Solutions:**

1. **Service stuck in PAUSED state:**
   ```powershell
   # Restart the service
   nssm restart NetTraceService
   
   # Or complete reset
   nssm stop NetTraceService
   nssm remove NetTraceService confirm
   NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true
   ```

2. **"Service already exists" error:**
   ```powershell
   # Force reinstall
   nssm remove NetTraceService confirm
   NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true
   ```

3. **Cross-user session monitoring:**
   ```powershell
   # From any user session
   Get-Service NetTraceService
   nssm status NetTraceService
   Get-NetTraceStatus
   ```

#### Persistence Examples

**Basic Persistence Setup:**
```powershell
# Start persistent capture (survives logout & reboot)
NetTrace -File 3 -FileSize 50 -Path "C:\NetworkTraces" -Persistence $true -Log

# Expected output:
# Windows Service persistent trace started successfully.
# Path: C:\NetworkTraces
# Max Files: 3
# Max Size: 50 MB
# True Windows Service persistence: Enabled
```

**Enterprise Persistence Deployment:**
```powershell
# Production server monitoring
NetTrace -File 10 -FileSize 100 -Path "D:\NetworkLogs\Production" -Persistence $true -Log -Verbose

# Service continues running even after:
# - Administrator logout
# - RDP session disconnect  
# - System maintenance reboot
# - User account changes
```

**Multi-User Session Testing:**
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

### Logging (-Log)

Enable detailed activity logging for troubleshooting and monitoring:

```powershell
# Start with logging enabled
NetTrace -File 3 -FileSize 50 -Path "C:\NetworkTraces" -Log

# Monitor logs in real-time
Get-Content "C:\NetworkTraces\NetTrace_*.log" -Wait -Tail 5

# Check recent activity
Get-Content "C:\NetworkTraces\NetTrace_*.log" -Tail 20
```

**Log File Locations:**
- **Activity Logs:** `C:\NetworkTraces\NetTrace_YYYY-MM-DD_HHMMSS.log`
- **Service Logs:** `C:\ProgramData\NetTrace\service.log`
- **NSSM Logs:** `C:\ProgramData\NetTrace\service_logs\service_stdout.log`

### Verbose Output (-Verbose)

Enable detailed output for troubleshooting and monitoring:

```powershell
# Start with verbose output
NetTrace -File 3 -FileSize 50 -Path "C:\NetworkTraces" -Verbose

# Stop with verbose output
NetTrace -Stop -Verbose
```

**Verbose Output Includes:**
- Service configuration details
- NSSM operations and status
- File creation and rotation events
- Service validation steps
- Detailed error information

## Service Management & Monitoring

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

## Troubleshooting

### Common Issues and Solutions

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

### Clean Slate - Complete Reset

When troubleshooting or starting fresh, use this comprehensive clean slate procedure to remove all NetTrace components, services, and data:

### **Complete NetTrace Reset Script**

```powershell
# ========================================
# NetTrace Complete Clean Slate Procedure
# ========================================

Write-Host "=== NetTrace Clean Slate Reset ===" -ForegroundColor Cyan
Write-Host "This will completely remove all NetTrace components" -ForegroundColor Yellow

# Stop any running NetTrace services
Write-Host "`n1. Stopping NetTrace services..." -ForegroundColor Green
nssm stop NetTraceService 2>$null
Stop-Service -Name NetTraceService -Force -ErrorAction SilentlyContinue

# Remove NSSM service completely
Write-Host "2. Removing NSSM service..." -ForegroundColor Green
nssm remove NetTraceService confirm 2>$null

# Alternative removal if NSSM fails
Write-Host "3. Alternative service removal..." -ForegroundColor Green
sc delete NetTraceService 2>$null

# Remove all NetTrace service data and configuration
Write-Host "4. Removing service data and configuration..." -ForegroundColor Green
Remove-Item "C:\ProgramData\NetTrace" -Recurse -Force -ErrorAction SilentlyContinue

# Clean any existing trace files from previous tests
Write-Host "5. Cleaning test directories..." -ForegroundColor Green
Remove-Item "C:\NetTrace-Tests" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\NetworkTraces" -Recurse -Force -ErrorAction SilentlyContinue

# Remove any temporary NSSM installations
Write-Host "6. Removing temporary NSSM files..." -ForegroundColor Green
Remove-Item "$env:TEMP\nssm*" -Recurse -Force -ErrorAction SilentlyContinue

# Uninstall all versions of NetTrace module
Write-Host "7. Uninstalling NetTrace modules..." -ForegroundColor Green
Get-Module NetTrace -ListAvailable | ForEach-Object { 
    Write-Host "  Removing NetTrace version $($_.Version)" -ForegroundColor Yellow
    Uninstall-Module -Name NetTrace -RequiredVersion $_.Version -Force -ErrorAction SilentlyContinue
}

# Force remove any remaining NetTrace modules
Write-Host "8. Force removing remaining modules..." -ForegroundColor Green
Uninstall-Module NetTrace -AllVersions -Force -ErrorAction SilentlyContinue

# Remove imported NetTrace modules from current session
Write-Host "9. Clearing session modules..." -ForegroundColor Green
Remove-Module NetTrace -Force -ErrorAction SilentlyContinue

# Clear PowerShell module cache
Write-Host "10. Clearing module cache..." -ForegroundColor Green
$env:PSModulePath -split ';' | ForEach-Object {
    $netTracePath = Join-Path $_ "NetTrace"
    if (Test-Path $netTracePath) {
        Write-Host "  Removing cached NetTrace from: $netTracePath" -ForegroundColor Yellow
        Remove-Item $netTracePath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Verification
Write-Host "`n=== Verification ===" -ForegroundColor Cyan

# Verify no NetTrace services exist
Write-Host "11. Checking for remaining services..." -ForegroundColor Green
$services = Get-Service -Name "*NetTrace*" -ErrorAction SilentlyContinue
if ($services) {
    Write-Host "  WARNING: NetTrace services still exist:" -ForegroundColor Red
    $services | Format-Table Name, Status, StartType
} else {
    Write-Host "  ✅ No NetTrace services found" -ForegroundColor Green
}

# Verify no NetTrace modules are loaded
Write-Host "12. Checking for remaining modules..." -ForegroundColor Green
$modules = Get-Module NetTrace -ListAvailable
if ($modules) {
    Write-Host "  WARNING: NetTrace modules still exist:" -ForegroundColor Red
    $modules | Format-Table Name, Version, ModuleBase
} else {
    Write-Host "  ✅ No NetTrace modules found" -ForegroundColor Green
}

# Verify no configuration files exist
Write-Host "13. Checking configuration directories..." -ForegroundColor Green
if (Test-Path "C:\ProgramData\NetTrace") {
    Write-Host "  WARNING: NetTrace configuration still exists" -ForegroundColor Red
} else {
    Write-Host "  ✅ No configuration files found" -ForegroundColor Green
}

# Verify no test directories exist
Write-Host "14. Checking test directories..." -ForegroundColor Green
$testDirs = @("C:\NetTrace-Tests", "C:\NetworkTraces")
$remainingDirs = $testDirs | Where-Object { Test-Path $_ }
if ($remainingDirs) {
    Write-Host "  WARNING: Test directories still exist: $($remainingDirs -join ', ')" -ForegroundColor Red
} else {
    Write-Host "  ✅ No test directories found" -ForegroundColor Green
}

Write-Host "`n=== Clean Slate Complete ===" -ForegroundColor Cyan
Write-Host "You can now perform a fresh NetTrace installation" -ForegroundColor Green
```

### **Quick Clean Slate (One-Liner)**

For a fast reset without verbose output:

```powershell
# Quick clean slate - single command
nssm stop NetTraceService 2>$null; nssm remove NetTraceService confirm 2>$null; sc delete NetTraceService 2>$null; Remove-Item "C:\ProgramData\NetTrace" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item "C:\NetTrace-Tests" -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item "C:\NetworkTraces" -Recurse -Force -ErrorAction SilentlyContinue; Uninstall-Module NetTrace -AllVersions -Force -ErrorAction SilentlyContinue; Remove-Module NetTrace -Force -ErrorAction SilentlyContinue
```

### **Selective Clean Slate Options**

#### **Service Only Reset**
```powershell
# Remove only NetTrace service (keep module installed)
nssm stop NetTraceService 2>$null
nssm remove NetTraceService confirm 2>$null
Remove-Item "C:\ProgramData\NetTrace" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Service reset complete. Module remains installed." -ForegroundColor Green
```

#### **Module Only Reset**
```powershell
# Remove only NetTrace module (keep service if needed)
Uninstall-Module NetTrace -AllVersions -Force -ErrorAction SilentlyContinue
Remove-Module NetTrace -Force -ErrorAction SilentlyContinue
Write-Host "Module reset complete. Service remains if installed." -ForegroundColor Green
```

#### **Test Data Reset**
```powershell
# Remove only test data and trace files
Remove-Item "C:\NetTrace-Tests" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\NetworkTraces" -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem "C:\" -Filter "NetTrace_*.log" | Remove-Item -Force -ErrorAction SilentlyContinue
Write-Host "Test data reset complete. Service and module remain." -ForegroundColor Green
```

### **Fresh Installation After Clean Slate**

After running the clean slate procedure:

```powershell
# 1. Fresh module installation
Install-Module -Name NetTrace -Force

# 2. Verify installation
Get-Module NetTrace -ListAvailable

# 3. Import module
Import-Module NetTrace

# 4. Test basic functionality
NetTrace -File 2 -FileSize 10 -Path "C:\NetworkTraces" -Log

# 5. Test persistence functionality
NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true -Log
```

### **When to Use Clean Slate**

Use the clean slate procedure when experiencing:

- ✅ **Service stuck in PAUSED state**
- ✅ **"Service already exists" errors**
- ✅ **Parameter configuration issues**
- ✅ **Module version conflicts**
- ✅ **NSSM installation problems**
- ✅ **Cross-user session issues**
- ✅ **Persistent configuration errors**
- ✅ **Before major version upgrades**
- ✅ **When switching test environments**

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

## Reference

### Command Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-File` | int | Yes* | Maximum number of trace files to maintain |
| `-FileSize` | int | Yes* | Maximum size of each trace file in MB (min 10MB) |
| `-Path` | string | Yes* | Directory path where trace files will be stored |
| `-Stop` | switch | No | Stops the currently running trace |
| `-Log` | switch | No | Enables detailed activity logging |
| `-LogNetshOutput` | switch | No | Logs netsh trace output to file |
| `-Persistence` | bool | No | Enables persistent capture (survives reboot) |
| `-Verbose` | switch | No | Shows detailed information |

*Required when starting a trace (not when using `-Stop`)

### Return Values

The `NetTrace` command returns a hashtable with the following properties:

| Property | Type | Description |
|----------|------|-------------|
| `FilesCreated` | int | Number of trace files created |
| `FilesRolled` | int | Number of files rotated due to size limits |
| `Success` | bool | Whether the operation completed successfully |
| `Persistence` | bool | Whether persistence mode was enabled |
| `Mode` | string | Operation mode ("Job" or "WindowsService") |

### File Locations

| Component | Location | Description |
|-----------|----------|-------------|
| **Trace Files** | `C:\NetworkTraces\*.etl` | Network trace capture files |
| **Activity Logs** | `C:\NetworkTraces\NetTrace_*.log` | Detailed activity logs (with `-Log`) |
| **Service Logs** | `C:\ProgramData\NetTrace\service.log` | Windows Service activity logs |
| **NSSM** | `C:\ProgramData\NetTrace\NSSM\nssm.exe` | Non-Sucking Service Manager |
| **Service Config** | `C:\ProgramData\NetTrace\service_config.json` | Service configuration file |
| **Service Status** | `C:\ProgramData\NetTrace\service_status.json` | Current service status |

### Service States

| State | Description | Action Required |
|-------|-------------|----------------|
| **Running** | Service is active and capturing | None - working normally |
| **Stopped** | Service is not running | Start with `NetTrace` command |
| **Paused** | Service encountered an error | Check logs and restart |
| **Not Installed** | Service not yet installed | First use will auto-install |

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