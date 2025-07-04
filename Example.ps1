# NetTrace Module - Basic Usage Example
# Version: 1.1.0
# Author: Naveed Khan
# Company: Hogwarts

# Import the NetTrace module
Import-Module .\NetTrace.psd1 -Force

Write-Output "NetTrace Module - Basic Usage Example"
Write-Output "Version: 1.1.0"
Write-Output "Author: Naveed Khan"
Write-Output "Company: Hogwarts"
Write-Output ""

Write-Output "This example demonstrates basic NetTrace functionality:"
Write-Output "1. Starting a network trace with circular file management"
Write-Output "2. Monitoring the trace progress"
Write-Output "3. Stopping the trace"
Write-Output ""

# Configuration
$TracePath = "C:\Traces\Example"
$MaxFiles = 3
$MaxSizeMB = 25

Write-Output "Configuration:"
Write-Output "  Path: $TracePath"
Write-Output "  Max Files: $MaxFiles"
Write-Output "  Max Size: $MaxSizeMB MB each"
Write-Output ""

# Create trace directory if it doesn't exist
if (-not (Test-Path $TracePath)) {
    New-Item -Path $TracePath -ItemType Directory -Force | Out-Null
    Write-Output "Created trace directory: $TracePath"
}

Write-Output "Starting NetTrace..."
Write-Output "This will create up to $MaxFiles files of $MaxSizeMB MB each"
Write-Output "Files will be replaced in circular fashion when limit is reached"
Write-Output ""

# Start the trace
try {
    NetTrace -File $MaxFiles -FileSize $MaxSizeMB -Path $TracePath -Verbose
    Write-Output "NetTrace started successfully!"
    Write-Output ""
    
    Write-Output "The trace is now running in the background."
    Write-Output "You can:"
    Write-Output "- Check the trace directory for .etl files"
    Write-Output "- Monitor file creation and rotation"
    Write-Output "- Use 'NetTrace -Stop' to stop the trace"
    Write-Output ""
    
    Write-Output "Example commands to try while trace is running:"
    Write-Output "  Get-ChildItem '$TracePath' -Filter '*.etl'"
    Write-Output "  NetTrace -Stop"
    Write-Output ""
    
} catch {
    Write-Error "Failed to start NetTrace: $($_.Exception.Message)"
    exit 1
}

Write-Output "Example completed. Use 'NetTrace -Stop' to stop the trace when done." 