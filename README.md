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

## Requirements

- **Windows 10/11** with netsh utility
- **PowerShell 5.1** or PowerShell 7+
- **Administrator privileges** (required for network tracing)

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
- **`-Persistence`**: Enables persistent capture that continues after system reboot (optional)
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
The `-Persistence` parameter enables network traces that continue after system reboot using the native netsh trace `persistent=yes` parameter. This feature is ideal for long-running captures that need to survive user session termination and system reboots.

### How It Works
- **Native Integration**: Uses netsh trace's built-in `persistent=yes` parameter
- **Automatic Resume**: Capture automatically resumes after system reboot
- **Session Independence**: Continues even if user logs out or session terminates
- **File Continuity**: Maintains the same file rotation and circular management

### Usage
```powershell
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence true
```

### Benefits
- **Long-term Monitoring**: Ideal for extended network analysis
- **System Reboot Survival**: Capture continues through maintenance windows
- **Session Independence**: No need to keep PowerShell session active
- **Production Ready**: Suitable for enterprise monitoring scenarios

### Recommendations
- **File Size**: Use `-FileSize >= 10MB` for optimal performance with persistence
- **Monitoring**: Combine with `-Log` parameter for comprehensive tracking
- **Storage**: Ensure adequate disk space for extended captures
- **Cleanup**: Remember to use `NetTrace -Stop` when capture is complete

### Example Output
```powershell
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence true -Log
```
**Output:**
```
Starting network trace...
Path: C:\Traces
Max Files: 3
Max Size: 10 MB
Persistence: Enabled (capture will resume after reboot)
Trace monitoring started in background.
All output is being logged to: C:\Traces\NetTrace_2025-06-28_145500.log
Use 'NetTrace -Stop' to stop the trace.
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
NetTrace -File 3 -FileSize 10 -Path "C:\Traces" -Persistence true -Log
```
**Creates persistent network trace that continues after system reboot with detailed logging**

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

## Files in This Module

| File | Purpose |
|------|---------|
| `NetTrace.psm1` | Main module functionality |
| `NetTrace.psd1` | Module manifest |
| `NetTrace-Service.ps1` | Windows Service implementation for persistent operation |
| `NetTrace-ServiceRunner.ps1` | Service installation and management script |
| `NetTrace-ScheduledTask.ps1` | Scheduled Task implementation for automated tracing |
| `PERSISTENT_SETUP_GUIDE.md` | Comprehensive guide for service and task setup |
| `Example.ps1` | Usage examples |
| `Test-NetTrace-Complete.ps1` | Comprehensive test suite with interactive menu |
| `Generate-NetworkTraffic.ps1` | Network traffic generator for testing |
| `Validate-PublishReadiness.ps1` | PowerShell Gallery publication validation script |
| `SCRIPT_ANALYZER_FIXES.md` | PSScriptAnalyzer compliance fixes documentation |
| `PUBLICATION_SUMMARY.md` | Publication process summary and notes |
| `PUBLISH_GUIDE.md` | PowerShell Gallery publication instructions |
| `README.md` | Complete documentation (this file) |
| `LICENSE` | MIT license file |

## License

This module is provided as-is for educational and administrative purposes.

## Version History

- **v1.2.0**: Added persistence feature for long-running captures
  - Added `-Persistence` parameter for captures that survive system reboot
  - Integrated native netsh trace `persistent=yes` parameter
  - Enhanced logging to include persistence status and configuration
  - Updated documentation with comprehensive persistence feature guide
  - Added persistence examples and usage recommendations
- **v1.1.1**: Improved user experience and admin privilege handling
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