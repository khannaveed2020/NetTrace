# How to Test the NetTrace Module

## Prerequisites
⚠️ **IMPORTANT**: NetTrace requires Administrator privileges because it uses `netsh trace` which needs admin access.

## Step-by-Step Testing Guide

### 1. **Open PowerShell as Administrator**
```powershell
# Right-click PowerShell and select "Run as Administrator"
# Or use Windows+X, then select "Windows PowerShell (Admin)"
```

### 2. **Navigate to Module Directory**
```powershell
cd "E:\Cursor\PowerShell Modules\NetTraces"
```

### 3. **Import the Module**
```powershell
# Remove any existing version first
Remove-Module NetTrace -Force -ErrorAction SilentlyContinue

# Import the updated module
Import-Module .\NetTrace.psd1 -Force
```

### 4. **Create Test Directory**
```powershell
# Create a test directory for traces
$testPath = "C:\Traces"
if (!(Test-Path $testPath)) {
    New-Item -Path $testPath -ItemType Directory -Force
}
```

### 5. **Test Basic Functionality**

#### **Test 1: Start Trace (Non-Blocking)**
```powershell
# This should return immediately and not block the console
NetTrace -File 2 -FileSize 10 -Path "C:\Traces"
```

**Expected Output:**
```
Trace monitoring started in background.
All output is being logged to: C:\Traces\NetTrace_2025-06-28_HHMMSS.log
Use 'NetTrace -Stop' to stop the trace.
You can monitor progress with: Get-Content 'C:\Traces\NetTrace_2025-06-28_HHMMSS.log' -Wait

PS C:\> █  # Console should be immediately available
```

#### **Test 2: Verify Console is Free**
```powershell
# Try running other commands - this should work immediately
Get-Date
Get-Process | Select-Object -First 5
Write-Host "Console is working!" -ForegroundColor Green
```

#### **Test 3: Monitor Log File (Optional)**
```powershell
# In the same or another PowerShell window, monitor the log file
Get-Content "C:\Traces\NetTrace_*.log" -Wait
```

**Expected Log Content:**
```
NetTrace session started at 06/28/2025 14:55:00
Command: NetTrace -File 2 -FileSize 10 -Path 'C:\Traces'
============================================================

14:55:01 - Creating File #1 : COMPUTERNAME_28-06-25-145501.etl
14:55:01 - Netsh trace started for: COMPUTERNAME_28-06-25-145501.etl
14:55:01 - Monitoring file size (limit: 10 MB)...
14:55:02 - File: COMPUTERNAME_28-06-25-145501.etl - Size: 0.1 MB / 10 MB
# ... continues with size updates ...
```

#### **Test 4: Stop Trace**
```powershell
# This should work properly without CTRL+C
NetTrace -Stop
```

**Expected Output:**
```
Trace stopped.
Final logs saved to: C:\Traces\NetTrace_2025-06-28_HHMMSS.log
```

### 6. **Test with Verbose Output**
```powershell
# Test with verbose mode
NetTrace -File 2 -FileSize 10 -Path "C:\Traces" -Verbose
```

### 7. **Test with Netsh Logging**
```powershell
# Test with detailed netsh logging
NetTrace -File 2 -FileSize 10 -Path "C:\Traces" -LogNetshOutput
```

This creates an additional `netsh_trace.log` file with technical details.

### 8. **Test Circular File Management**
```powershell
# Start trace and let it run to see file rotation
NetTrace -File 2 -FileSize 10 -Path "C:\Traces"

# Generate network traffic to fill files faster (optional)
.\Generate-NetworkTraffic.ps1

# Watch the log file to see circular management
Get-Content "C:\Traces\NetTrace_*.log" -Wait
```

## Verification Checklist

### ✅ **Console Behavior**
- [ ] Command returns immediately (no blocking)
- [ ] Console prompt is available for other commands
- [ ] No excessive netsh output in console
- [ ] Clean, minimal output shown

### ✅ **Log File Creation**
- [ ] Log file created automatically with timestamp
- [ ] All activity logged with timestamps
- [ ] File creation and rotation logged
- [ ] Error messages logged if any occur

### ✅ **Stop Functionality**
- [ ] `NetTrace -Stop` works without CTRL+C
- [ ] Stop action logged to file
- [ ] Clean termination message shown

### ✅ **File Management**
- [ ] ETL files created with correct naming
- [ ] Files rotate when size limit reached
- [ ] Oldest files deleted when limit exceeded
- [ ] Circular management working correctly

## Troubleshooting

### **If Import Fails**
```powershell
# Check execution policy
Get-ExecutionPolicy

# If restricted, temporarily allow
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **If "Access Denied" Errors**
- Ensure PowerShell is running as Administrator
- Check that you have admin rights on the system

### **If Module Not Found**
```powershell
# Verify you're in the correct directory
Get-Location
Get-ChildItem *.psd1
```

### **If Netsh Fails**
- Ensure Windows has netsh trace capability
- Check if any other network traces are running

## Quick Test Script

You can also run this quick test:

```powershell
# Quick comprehensive test
Write-Host "Testing NetTrace Module..." -ForegroundColor Green

# Import module
Import-Module .\NetTrace.psd1 -Force

# Start trace
Write-Host "Starting trace..." -ForegroundColor Yellow
NetTrace -File 2 -FileSize 10 -Path "C:\Traces"

# Wait a moment
Start-Sleep -Seconds 5

# Check if console is responsive
Write-Host "Console is responsive!" -ForegroundColor Green

# Stop trace
Write-Host "Stopping trace..." -ForegroundColor Yellow
NetTrace -Stop

# Check results
Write-Host "Test completed. Check C:\Traces for files." -ForegroundColor Green
Get-ChildItem "C:\Traces" | Select-Object Name, Length, LastWriteTime
```

## Expected Results

After successful testing, you should see:
1. **Clean console experience** - no blocking, minimal output
2. **Responsive PowerShell** - can run other commands immediately
3. **Log files created** - timestamped activity logs
4. **ETL files created** - actual network trace files
5. **Proper stop functionality** - works without CTRL+C

The module should now behave like a professional background service with comprehensive logging! 