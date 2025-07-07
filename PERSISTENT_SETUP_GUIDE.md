# NetTrace Persistent Operation Setup Guide

This guide shows you how to keep NetTrace running even when user sessions are disconnected or logged out.

## 🏆 **Recommended: Windows Service (Best Option)**

### Why Windows Service?
- ✅ **Most Reliable**: Survives user logouts, reboots, and system crashes
- ✅ **Automatic Recovery**: Windows automatically restarts failed services
- ✅ **System Integration**: Full integration with Windows Service Manager
- ✅ **Event Logging**: Proper Windows Event Log integration
- ✅ **Security**: Runs under SYSTEM account with appropriate privileges

### Setup Steps

1. **Install as Service** (Run as Administrator):
   ```powershell
   .\NetTrace-Service.ps1 -Action Install -TracePath "C:\NetTrace\Production" -MaxFiles 20 -MaxSizeMB 500 -EnableLogging
   ```

2. **Start the Service**:
   ```powershell
   .\NetTrace-Service.ps1 -Action Start
   ```

3. **Check Status**:
   ```powershell
   .\NetTrace-Service.ps1 -Action Status
   ```

4. **Monitor via Services.msc**:
   - Open `services.msc`
   - Find "NetTrace Network Monitoring Service"
   - Set to "Automatic (Delayed Start)" for best performance

### Service Management Commands

```powershell
# Install with custom settings
.\NetTrace-Service.ps1 -Action Install -TracePath "D:\NetworkTraces" -MaxFiles 50 -MaxSizeMB 1000

# Start/Stop/Status
.\NetTrace-Service.ps1 -Action Start
.\NetTrace-Service.ps1 -Action Stop
.\NetTrace-Service.ps1 -Action Status

# Uninstall
.\NetTrace-Service.ps1 -Action Uninstall
```

---

## 🔄 **Alternative: Scheduled Task**

### Why Scheduled Task?
- ✅ **Simpler Setup**: Easier to configure than services
- ✅ **User Context**: Can run under specific user accounts
- ✅ **Flexible Triggers**: Multiple trigger options
- ❌ **Less Reliable**: More prone to failures than services

### Setup Steps

1. **Install as Scheduled Task** (Run as Administrator):
   ```powershell
   .\NetTrace-ScheduledTask.ps1 -Action Install -TracePath "C:\NetTrace\Scheduled" -MaxFiles 15 -MaxSizeMB 300
   ```

2. **Start the Task**:
   ```powershell
   .\NetTrace-ScheduledTask.ps1 -Action Start
   ```

3. **Monitor via Task Scheduler**:
   - Open `taskschd.msc`
   - Find "NetTrace-Monitoring"
   - Review execution history

---

## 📊 **Monitoring Your Persistent NetTrace**

### 1. **Check Service/Task Status**
```powershell
# Service status
Get-Service NetTrace
.\NetTrace-Service.ps1 -Action Status

# Task status
Get-ScheduledTask -TaskName "NetTrace-Monitoring"
.\NetTrace-ScheduledTask.ps1 -Action Status
```

### 2. **Monitor Trace Files**
```powershell
# Check trace files
Get-ChildItem "C:\NetTrace\Production\*.etl" | Sort-Object LastWriteTime -Descending | Select-Object Name, Length, LastWriteTime

# Monitor file creation in real-time
Get-ChildItem "C:\NetTrace\Production\*.etl" | Sort-Object LastWriteTime -Descending | Select-Object Name, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}}, LastWriteTime
```

### 3. **Check Event Logs**
```powershell
# Service events
Get-EventLog -LogName Application -Source "NetTrace Service" -Newest 10

# Task events
Get-EventLog -LogName Application -Source "NetTrace Task" -Newest 10
```

### 4. **Monitor Log Files** (if logging enabled)
```powershell
# Real-time log monitoring
Get-Content "C:\NetTrace\Production\*.log" -Wait -Tail 20
```

---

## 🛠️ **Advanced Configuration**

### **High-Volume Production Setup**
```powershell
# Large enterprise setup
.\NetTrace-Service.ps1 -Action Install -TracePath "E:\NetworkTraces" -MaxFiles 100 -MaxSizeMB 2000 -EnableLogging
```

### **Resource-Constrained Setup**
```powershell
# Minimal resource usage
.\NetTrace-Service.ps1 -Action Install -TracePath "C:\Traces" -MaxFiles 5 -MaxSizeMB 50
```

### **Development/Testing Setup**
```powershell
# Development environment
.\NetTrace-Service.ps1 -Action Install -TracePath "C:\Dev\Traces" -MaxFiles 10 -MaxSizeMB 100 -EnableLogging
```

---

## 🔧 **Troubleshooting**

### **Service Won't Start**
1. Check Windows Event Log:
   ```powershell
   Get-EventLog -LogName System -Source "Service Control Manager" | Where-Object {$_.Message -like "*NetTrace*"}
   ```

2. Verify PowerShell execution policy:
   ```powershell
   Get-ExecutionPolicy -List
   ```

3. Test manual execution:
   ```powershell
   Import-Module .\NetTrace.psd1 -Force
   NetTrace -File 5 -FileSize 100 -Path "C:\Test" -Verbose
   ```

### **High Resource Usage**
1. Reduce file size or count:
   ```powershell
   .\NetTrace-Service.ps1 -Action Uninstall
   .\NetTrace-Service.ps1 -Action Install -MaxFiles 5 -MaxSizeMB 50
   ```

2. Disable logging if not needed:
   ```powershell
   # Reinstall without -EnableLogging
   .\NetTrace-Service.ps1 -Action Install -TracePath "C:\Traces" -MaxFiles 10 -MaxSizeMB 100
   ```

### **Trace Files Not Created**
1. Check directory permissions:
   ```powershell
   Test-Path "C:\NetTrace\Production" -PathType Container
   ```

2. Verify netsh trace permissions:
   ```powershell
   netsh trace show status
   ```

---

## 📋 **Best Practices**

### **Storage Management**
- Use dedicated drive for trace files (separate from OS)
- Monitor disk space regularly
- Set appropriate MaxFiles based on available storage

### **Performance Optimization**
- Use SSD storage for better I/O performance
- Adjust MaxSizeMB based on network activity
- Consider network peak hours for sizing

### **Security**
- Run service under least-privilege account when possible
- Secure trace file directory with appropriate ACLs
- Regular security audits of trace data

### **Maintenance**
- Regular service health checks
- Archive old trace files
- Monitor Windows Event Logs
- Test service recovery procedures

---

## 🚀 **Quick Start Commands**

### **Production Deployment**
```powershell
# 1. Install as service
.\NetTrace-Service.ps1 -Action Install -TracePath "C:\NetTrace\Prod" -MaxFiles 30 -MaxSizeMB 500 -EnableLogging

# 2. Start service
.\NetTrace-Service.ps1 -Action Start

# 3. Verify operation
.\NetTrace-Service.ps1 -Action Status
Get-ChildItem "C:\NetTrace\Prod\*.etl"
```

### **Development/Testing**
```powershell
# 1. Install as scheduled task
.\NetTrace-ScheduledTask.ps1 -Action Install -TracePath "C:\NetTrace\Dev" -MaxFiles 10 -MaxSizeMB 100 -EnableLogging

# 2. Start task
.\NetTrace-ScheduledTask.ps1 -Action Start

# 3. Monitor
.\NetTrace-ScheduledTask.ps1 -Action Status
```

---

## 🎯 **Summary**

| Method | Reliability | Setup Complexity | Best For |
|--------|-------------|------------------|----------|
| **Windows Service** | ⭐⭐⭐⭐⭐ | Medium | Production environments |
| **Scheduled Task** | ⭐⭐⭐⭐ | Easy | Development/testing |

**Recommendation**: Use Windows Service for production environments where maximum reliability is required. Use Scheduled Task for development or testing scenarios where easier management is preferred.

Both methods ensure NetTrace continues running even when:
- User logs out
- RDP sessions disconnect
- System restarts (automatic restart)
- PowerShell sessions end

Choose the method that best fits your environment and requirements! 