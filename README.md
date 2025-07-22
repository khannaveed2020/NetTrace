# NetTrace PowerShell Module

A professional PowerShell module for Windows network tracing using the native `netsh trace` utility with circular file management and non-blocking background operation.

## Features

- **Non-Blocking Operation**: Runs in background, returns console immediately
- **Automatic Log Files**: All activity logged to timestamped files
- **Circular File Management**: Maintains fixed number of files, deletes oldest when full
- **Clean Console Output**: No netsh spam, minimal user-friendly messages
- **Professional Stop Functionality**: Use `NetTrace -Stop` (no more CTRL+C needed)
- **Optional Activity Logging**: Enable detailed progress logging with `-Log` parameter
- **Optional Technical Logging**: Save netsh technical details when needed
- **Real-time Monitoring**: Optional log file monitoring with `Get-Content -Wait`

## Version 1.3.5 - Production-Ready Persistence

🎉 **LATEST STABLE RELEASE**: Version 1.3.5 delivers bulletproof Windows Service persistence with comprehensive parameter validation and robust NSSM service state management. This version eliminates all parameter passing issues and provides enterprise-grade reliability.

### Key Improvements in v1.3.5:
- ✅ **Fixed Parameter Scoping Issues** - Resolved dot-sourcing parameter conflicts
- ✅ **Enhanced Service State Management** - Automatic recovery from PAUSED states
- ✅ **Robust Parameter Validation** - Prevents empty configuration values
- ✅ **Cross-User Session Support** - Monitor and control from any user session
- ✅ **Comprehensive Error Diagnostics** - Detailed error reporting and recovery
- ✅ **Race Condition Handling** - Eliminates service start/stop conflicts
- ✅ **One-Command Operation** - Single command installs, configures, and starts service

### Production Features:
- ✅ **Genuine Windows Service** - always runs as LocalSystem (SYSTEM context)
- ✅ **Survives user logouts** - continues monitoring when all users log off
- ✅ **Survives system reboots** - auto-starts after system restart
- ✅ **Automatic service management** - downloads and configures NSSM automatically
- ✅ **Perfect file rotation** - maintains exact file counts and sizes
- ✅ **Cross-session persistence** - works across RDP/user session changes

All existing commands work exactly the same - this version provides enhanced reliability with no breaking changes.

## Requirements

- **Windows 10/11** with netsh utility
- **PowerShell 5.1** or PowerShell 7+
- **Administrator privileges** (required for network tracing)

## Quick Reference - Persistence Mode

**Start persistent trace (survives user logout & reboot):**
```powershell
NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true -Log
```

**Monitor service status:**
```powershell
Get-Service NetTraceService; nssm status NetTraceService
```

**Check trace files:**
```powershell
Get-ChildItem "C:\NetworkTraces" | Select-Object Name, Length, LastWriteTime
```

**Stop persistent trace:**
```powershell
NetTrace -Stop
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

## Usage

### Quick Start - Persistence Mode

For **true persistent network tracing** that survives user logouts and system reboots:

```powershell
# Single command - automatic service installation and start
NetTrace -File 3 -FileSize 10 -Path "C:\NetworkTraces" -Persistence $true -Log -Verbose

# Monitor service status
Get-Service NetTraceService
nssm status NetTraceService

# Check trace files are being created
Get-ChildItem "C:\NetworkTraces" | Select-Object Name, Length, LastWriteTime

# Stop the persistent trace
NetTrace -Stop
```

**Service Monitoring Commands:**
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

### Basic Syntax

```powershell
NetTrace -File <integer> -FileSize <integer> -Path <string> [-Log] [-Verbose] [-LogNetshOutput]
NetTrace -Stop
```

### Parameters

- **`-File`**: Maximum number of trace files to maintain (circular buffer)
- **`-FileSize`**: Maximum size of each file in MB (minimum 10 MB due to netsh limitation)
- **`-Path`**: Directory path where trace files will be stored
- **`-Log`**: Enables detailed activity logging to timestamped log files (optional)
- **`-Verbose`**: Shows detailed progress information (optional)
- **`-LogNetshOutput`**: Saves netsh technical details to `netsh_trace.log` (optional)
- **`-Persistence`**: Enables persistent capture that continues after system reboot (optional). Accepts: $true/$false, true/false, or "true"/"false"
- **`-Stop`**: Stops the currently running trace

**Important**: Netsh trace has a minimum file size of 10MB. Values less than 10MB will cause netsh to default to 512MB files.

## Logging Options

### `-Log` Parameter (Activity Logging)
**Purpose**: Logs NetTrace module operations and file management activities.

**What it includes**:
- File creation and rotation events
- File size monitoring progress  
- Circular management (file deletions)
- Session start/stop information
- Error messages and summaries

**Log file**: `NetTrace_YYYY-MM-DD_HHMMSS.log`

**When to use**: 
- Monitor trace progress and file operations
- Troubleshoot NetTrace module behavior
- Track file creation/rotation statistics

### `-LogNetshOutput` Parameter (Technical Logging)
**Purpose**: Logs raw netsh trace command output and diagnostics.

**What it includes**:
- Raw netsh trace start/stop output
- Provider configuration details
- Windows networking trace diagnostics
- Low-level netsh error messages

**Log file**: `netsh_trace.log`

**When to use**:
- Debug netsh trace command failures
- Advanced Windows networking troubleshooting
- Capture technical details for support tickets

### No Logging (Default)
**Purpose**: Minimal disk I/O with lean operation.

**Benefits**:
- Faster performance (no log file writes)
- Reduced disk space usage
- Clean operation for production environments

## Persistence Feature

### Overview
The `-Persistence` parameter enables **true persistent network traces** that survive user session termination and system reboots using a Windows Service-based architecture. This advanced feature provides enterprise-grade persistence beyond what netsh trace's `persistent=yes` parameter alone can offer.

### How It Works
- **True Windows Service**: Uses NSSM (Non-Sucking Service Manager) for genuine Windows Service implementation
- **Always runs as LocalSystem**: The NetTrace service is installed to run as the LocalSystem (SYSTEM) account, guaranteeing persistence across logoff and reboot, regardless of which user installs it.
- **Complete Session Independence**: Runs in SYSTEM context, completely independent of user sessions
- **Automatic Service Management**: Downloads and configures NSSM automatically when needed
- **Persistent File Management**: File rotation and circular management continue regardless of user sessions
- **System Reboot Survival**: Service auto-starts after system reboot with full configuration
- **Native Integration**: Still uses netsh trace's `persistent=yes` parameter for optimal performance

### True Persistence vs Basic Persistence
| Feature | Basic (netsh only) | True Persistence (Service) |
|---------|-------------------|---------------------------|
| Survives reboot | ✅ | ✅ |
| Survives user logout | ❌ | ✅ |
| File rotation continues | ❌ | ✅ |
| Circular management | ❌ | ✅ |
| Session independence | ❌ | ✅ |

### Usage
```powershell
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence true
```

### Benefits
- **True Session Independence**: Continues even when all users log out
- **Complete File Management**: Automatic rotation and circular management persist
- **Enterprise Ready**: Suitable for production monitoring and long-term analysis
- **Maintenance Window Safe**: Survives system reboots and maintenance activities
- **Zero User Intervention**: Runs completely independently once started

### Service Management
The persistence feature automatically manages Windows Services behind the scenes:

```powershell
# Check service status
Get-NetTraceStatus

# Stop persistent trace (same command as always)
NetTrace -Stop
```

### Service Requirements
The Windows Service persistence feature has the following requirements:

- **NSSM**: Downloaded automatically from https://nssm.cc/ when needed
- **Administrator privileges**: Required for service installation and management
- **Windows Service Manager**: Uses standard Windows Service controls
- **Automatic installation**: Service is installed automatically when persistence is first requested

### Service Installation Details
When you first use `-Persistence true`, the module will:

1. **Download NSSM** from the official source (https://nssm.cc/)
2. **Install NetTrace Windows Service** using NSSM
3. **Configure service settings** for automatic startup and recovery
4. **Start the service** with your specified parameters

No manual service installation is required - everything is handled automatically.

### Recommendations
- **File Size**: Use `-FileSize >= 10MB` for optimal performance with persistence
- **Monitoring**: Combine with `-Log` parameter for comprehensive tracking
- **Storage**: Ensure adequate disk space for extended captures
- **Service Logs**: Check `$env:ProgramData\NetTrace\service.log` for service-level diagnostics
- **Cleanup**: Always use `NetTrace -Stop` when capture is complete

### Example Output
```powershell
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence true -Log
```
**Output:**
```
Starting Windows Service persistent network trace...
Path: C:\Traces
Max Files: 3
Max Size: 10 MB
True Windows Service persistence: Enabled (capture will survive user session termination and system reboots)
Windows Service persistent trace started successfully.
All output is being logged to: C:\Traces\NetTrace_2025-01-08_144228.log
You can monitor progress with: Get-Content 'C:\Traces\NetTrace_*.log' -Wait
Use 'NetTrace -Stop' to stop the Windows Service trace.
```

### Status Monitoring
Use the new `Get-NetTraceStatus` command for quick status checks:

```powershell
Get-NetTraceStatus
```
**Output:**
```
IsRunning     : True
FilesCreated  : 2
FilesRolled   : 1
Mode          : WindowsService
Path          : C:\Traces
MaxFiles      : 3
MaxSizeMB     : 10
Persistence   : True
LoggingEnabled: True
LastUpdate    : 2025-01-22 14:45:30
```

### Multi-User Session Testing
**Test persistence across user sessions:**

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

### Production Deployment Example
```powershell
# Production server network monitoring
NetTrace -File 5 -FileSize 100 -Path "D:\NetworkLogs\Production" -Persistence $true -Log -Verbose

# Expected file structure after 24 hours:
# D:\NetworkLogs\Production\
#   ├── ServerName_22-01-25-140530.etl (100 MB)
#   ├── ServerName_22-01-25-142545.etl (100 MB)  
#   ├── ServerName_22-01-25-144601.etl (100 MB)
#   ├── ServerName_22-01-25-150616.etl (100 MB)
#   ├── ServerName_22-01-25-152632.etl (85 MB - current)
#   └── NetTrace_2025-01-22_140525.log (activity log)

# Service continues running even after:
# - Administrator logout
# - RDP session disconnect  
# - System maintenance reboot
# - User account changes
```

## Examples

### Basic Usage (No Logging - Minimal Disk I/O)
```powershell
NetTrace -File 2 -FileSize 10 -Path "C:\Traces"
```
**Output:**
```
Trace monitoring started in background.
Logging is disabled. Use -Log parameter to enable detailed logging.
Use 'NetTrace -Stop' to stop the trace.

PS C:\> █  # Console immediately available
```

### With Activity Logging
```powershell
NetTrace -File 2 -FileSize 10 -Path "C:\Traces" -Log
```
**Output:**
```
Trace monitoring started in background.
All output is being logged to: C:\Traces\NetTrace_2025-06-28_145500.log
Use 'NetTrace -Stop' to stop the trace.
You can monitor progress with: Get-Content 'C:\Traces\NetTrace_2025-06-28_145500.log' -Wait

PS C:\> █  # Console immediately available
```

### With Verbose Output
```powershell
NetTrace -File 2 -FileSize 10 -Path "C:\Traces" -Verbose
```
**Shows additional startup information and detailed progress**

### With Technical Logging
```powershell
NetTrace -File 2 -FileSize 10 -Path "C:\Traces" -LogNetshOutput
```
**Creates additional `netsh_trace.log` with technical details**

### With Both Activity and Technical Logging
```powershell
NetTrace -File 2 -FileSize 10 -Path "C:\Traces" -Log -LogNetshOutput
```
**Creates both activity logs and technical netsh logs for comprehensive troubleshooting**

### With Persistence (Survives System Reboot)
```powershell
# All these formats work:
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence true -Log
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence $true -Log
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence "true" -Log
```
**Expected Output:**
```
Starting Windows Service persistent network trace...
Path: C:\Traces
Max Files: 3
Max Size: 10 MB
True Windows Service persistence: Enabled (capture will survive user session termination and system reboots)

NetTrace Windows Service installed successfully
  Service Name: NetTraceService
  Display Name: NetTrace Network Monitoring Service
  Startup Type: Automatic
  Service Type: Windows Service (NSSM)

Windows Service persistent trace started successfully.
  Path: C:\Traces
  Max Files: 3
  Max Size: 10 MB
All output is being logged to: C:\Traces\NetTrace_2025-01-22_165520.log
Use 'NetTrace -Stop' to stop the Windows Service trace.
```

### Real-World Enterprise Example
```powershell
# Enterprise network monitoring setup
NetTrace -File 10 -FileSize 50 -Path "D:\NetworkMonitoring\Production" -Persistence $true -Log -Verbose

# Monitor from different user session or after logout
Get-Service NetTraceService | Select-Object Name, Status, StartType
nssm status NetTraceService
Get-ChildItem "D:\NetworkMonitoring\Production" | Measure-Object Length -Sum

# Stop when analysis complete
NetTrace -Stop
```

### Monitor Progress (Optional - Requires `-Log` Parameter)
```powershell
# In same or different PowerShell window
Get-Content "C:\Traces\NetTrace_*.log" -Wait
```
**Note**: Progress monitoring requires the `-Log` parameter to be used when starting the trace.

### Stop Trace
```powershell
NetTrace -Stop
```
**Output:**
```
Trace stopped.
Final logs saved to: C:\Traces\NetTrace_2025-06-28_145500.log
```

### Check Status
```powershell
Get-NetTraceStatus
```
**Shows current trace status, file counts, and configuration for both job-based and service-based traces**

## How Circular File Management Works

1. **Creates files sequentially** until reaching the specified count (e.g., 2 files)
2. **When creating file #3**, automatically deletes the oldest file (#1)
3. **Continues indefinitely** maintaining only the specified number of files
4. **Runs until manually stopped** with `NetTrace -Stop`

**Example with 2 files:**
- Creates: `File #1`, `File #2`
- Creates: `File #3` → Deletes `File #1`
- Creates: `File #4` → Deletes `File #2`
- And so on...

## File Formats

### Network Trace Files
```
<computername>_dd-MM-yy-HHmmss.etl
```
**Examples:**
- `MYPC_28-06-25-145501.etl`
- `SERVER01_28-06-25-145616.etl`

### Activity Log Files (Only with `-Log` Parameter)
```
NetTrace_yyyy-MM-dd_HHmmss.log
```
**Examples:**
- `NetTrace_2025-06-28_145500.log`

**Note**: These files are only created when using the `-Log` parameter.

### Sample Log Content
```
NetTrace session started at 06/28/2025 14:55:00
Command: NetTrace -File 2 -FileSize 10 -Path 'C:\Traces'
============================================================

14:55:01 - Creating File #1 : MYPC_28-06-25-145501.etl
14:55:01 - Netsh trace started for: MYPC_28-06-25-145501.etl
14:55:01 - Monitoring file size (limit: 10 MB)...
14:55:02 - File: MYPC_28-06-25-145501.etl - Size: 1.2 MB / 10 MB
14:56:15 - Size limit reached! Rolling to new file...
14:56:16 - Creating File #2 : MYPC_28-06-25-145616.etl
14:56:17 - Creating File #3 : MYPC_28-06-25-145617.etl
14:56:17 - Removed oldest file: MYPC_28-06-25-145501.etl
...
```

## Testing

### Comprehensive Test Suite
```powershell
# Run the complete test suite with interactive menu
.\Test-NetTrace-Complete.ps1
```

**Available test options:**
- **Quick Test**: 2-3 minute basic functionality validation
- **Standard Test**: 5-10 minute comprehensive testing
- **Circular Test**: Manual circular file management demonstration
- **Parameter Test**: Input validation testing
- **Performance Test**: Console responsiveness validation
- **Full Test Suite**: Complete 15-20 minute regression testing

### Generate Network Traffic (for testing)
```powershell
# Create network activity to fill trace files faster
.\Generate-NetworkTraffic.ps1
```

## Advanced Features

### Windows Service Support
For persistent operation that survives user logouts and system reboots, the module includes Windows Service support:

```powershell
# Install and start the NetTrace service
.\NetTrace-ServiceRunner.ps1 -Install

# Stop and remove the service
.\NetTrace-ServiceRunner.ps1 -Uninstall
```

### Scheduled Task Support
For automated network tracing on a schedule:

```powershell
# Create scheduled task for automated tracing
.\NetTrace-ScheduledTask.ps1
```

### Setup Guide
For detailed instructions on setting up persistent operation, see:
- `PERSISTENT_SETUP_GUIDE.md` - Comprehensive guide for service and task setup

## Key Benefits

### ✅ **Professional User Experience**
- **Non-blocking console** - returns immediately
- **Clean output** - no netsh spam
- **Proper stop functionality** - no CTRL+C needed
- **Comprehensive logging** - all activity tracked

### ✅ **Enterprise Features**
- **Background operation** - doesn't interfere with other work
- **Automatic log management** - timestamped activity logs
- **Circular file management** - prevents disk space issues
- **Optional technical logging** - detailed troubleshooting data

### ✅ **Reliability**
- **Proper resource cleanup** - background jobs managed correctly
- **Error handling** - graceful failure handling
- **Administrator validation** - clear privilege requirements
- **File size validation** - prevents netsh default behavior

## Technical Architecture

- **Background Jobs**: PowerShell jobs handle monitoring without blocking console
- **Flag File Communication**: Clean job termination using temporary flag files
- **Output Capture**: All netsh output captured and redirected to log files
- **Circular Buffer**: Automatic oldest file deletion when limit exceeded

## Troubleshooting

### Common Issues

**"Access Denied" Errors**
- Ensure PowerShell is running as Administrator
- Verify you have admin rights on the system

**Module Import Fails**
```powershell
# Check execution policy
Get-ExecutionPolicy

# If restricted, allow for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Console Still Blocking**
- Verify you're using the latest version of the module
- Run `.\Simple-Test.ps1` to validate non-blocking behavior

**Files Not Created**
- Check that netsh trace is available on your system
- Ensure no other network traces are running
- Verify the target directory is writable

### Persistence Mode Troubleshooting

**Service Not Starting (SERVICE_PAUSED)**
```powershell
# Check service logs for errors
Get-Content "C:\ProgramData\NetTrace\service.log" -Tail 20

# Check Windows Event Logs
Get-WinEvent -LogName System -MaxEvents 10 | Where-Object {$_.ProviderName -like "*NetTrace*"}

# Restart service
nssm restart NetTraceService
```

**Service Shows Stopped But Files Still Growing**
- This is normal during service transitions
- Wait 30 seconds and check again
- Service may be in graceful shutdown mode

**Cross-User Session Monitoring**
```powershell
# From any user session, monitor service
Get-Service NetTraceService
nssm status NetTraceService

# Monitor files (works from any user since service runs as LocalSystem)
Get-ChildItem "C:\YourTracePath" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

**Service Configuration Issues**
```powershell
# Check if parameters were saved correctly
Get-Content "C:\ProgramData\NetTrace\service_config.json" | ConvertFrom-Json | Format-List

# If config shows empty values, restart NetTrace command
NetTrace -File 3 -FileSize 10 -Path "C:\YourPath" -Persistence $true -Log
```

**Clean Service Reset**
```powershell
# Complete service cleanup and reinstall
nssm stop NetTraceService
nssm remove NetTraceService confirm
Remove-Item "C:\ProgramData\NetTrace" -Recurse -Force -ErrorAction SilentlyContinue

# Reinstall with fresh configuration
NetTrace -File 3 -FileSize 10 -Path "C:\YourPath" -Persistence $true -Log
```

## Files in This Module

| File | Purpose |
|------|---------|
| `NetTrace.psm1` | Main module functionality with dual-mode operation support |
| `NetTrace.psd1` | Module manifest |
| `NetTrace-Service.ps1` | Windows Service implementation for true persistent operation |
| `NetTrace-ServiceRunner.ps1` | Service installation and management script |
| `README.md` | Complete documentation (this file) |
| `LICENSE` | MIT license file |

### Core Functions
- **`NetTrace`**: Main function with automatic persistence mode detection
- **`Get-NetTraceStatus`**: Quick status checking for both job-based and service-based traces

### Service Architecture
- **Job-based Mode**: Traditional PowerShell background jobs (default for non-persistent traces)
- **Service-based Mode**: Windows Services for true persistence (enabled with `-Persistence true`)
- **Automatic Detection**: Unified `NetTrace -Stop` command works with both modes

## License

This module is provided as-is for educational and administrative purposes.

## Version History

- **v1.3.5**: Production-Ready Persistence with Enhanced Reliability
  - **CRITICAL FIX**: Resolved parameter scoping issue where dot-sourcing NetTrace-ServiceRunner.ps1 overwrote function parameters
  - **Enhanced Service State Management**: Robust NSSM service state checking with automatic recovery from PAUSED states
  - **Comprehensive Parameter Validation**: Added validation to prevent empty configuration values that caused service failures
  - **Race Condition Handling**: Prevents "already running" errors and service conflicts during start/stop operations
  - **Cross-User Session Support**: Service monitoring and control works from any user session
  - **Detailed Error Diagnostics**: Enhanced error reporting with service log analysis and recovery suggestions
  - **One-Command Reliability**: Single command operation now works without manual intervention or service state conflicts
- **v1.3.4**: Parameter Type Conversion Fix
  - **Switch Parameter Fix**: Fixed boolean type conversion for LogNetshOutput and Log parameters between functions
  - **Debug Logging**: Added parameter debugging to trace function call flow
- **v1.3.3**: Service State Management Enhancement  
  - **NSSM State Handling**: Enhanced service status checking and automatic paused service recovery
  - **Parameter Validation**: Added comprehensive validation to prevent empty configuration values
- **v1.2.6**: Implemented true persistence using Windows Services
  - **True Persistence**: Service-based architecture for captures that survive user session termination and system reboots
  - **Enhanced -Persistence Parameter**: Now uses Windows Services for true session-independent operation
  - **New Command**: Added `Get-NetTraceStatus` for quick status checking without requiring -Log parameter
  - **Service Management**: Added `NetTrace-Service.ps1` and `NetTrace-ServiceRunner.ps1` for service operations
  - **Dual-Mode Operation**: Automatic detection between job-based and service-based persistence
  - **Backward Compatibility**: Existing functionality unchanged, enhanced persistence is opt-in
  - **Unified Stop Command**: Single `NetTrace -Stop` command works for both job-based and service-based traces
- **v1.2.5**: Added basic persistence feature for long-running captures
  - Added `-Persistence` parameter for captures that survive system reboot
  - Integrated native netsh trace `persistent=yes` parameter
  - Enhanced logging to include persistence status and configuration
  - Updated documentation with comprehensive persistence feature guide
  - Added persistence examples and usage recommendations
- **v1.2.4**: Improved user experience and admin privilege handling
  - Removed `#Requires -RunAsAdministrator` directive to allow module loading in non-admin sessions
  - Module now provides proper error message when run without admin privileges
  - Updated README with PowerShell Gallery installation instructions
  - Added comprehensive admin privilege clarification and usage instructions
  - Enhanced documentation for all module files and components
- **v1.1.0**: Enhanced logging control and production improvements
  - Added `-Log` parameter for optional activity logging
  - Fixed file counter accuracy issues  
  - Improved stop command reliability
  - Consolidated test suite into single interactive script
  - Enhanced documentation and help system
  - PowerShell Gallery publication ready
- **v1.0.0**: Production release with non-blocking operation and circular file management
  - Non-blocking operation with background jobs
  - Automatic circular file rotation
  - Comprehensive logging capabilities
  - Administrator privilege validation
- **v0.9.0**: Initial development version with basic functionality 