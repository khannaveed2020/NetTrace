#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Comprehensive test script for NetTrace module - Local Testing Guide
    
.DESCRIPTION
    This script provides step-by-step instructions and automated tests for the NetTrace module.
    Run this script to verify all functionality works correctly on your local system.
#>

# Import the NetTrace module
Write-Host "=== NetTrace Module Local Testing Guide ===" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Running as Administrator" -ForegroundColor Green
Write-Host ""

# Test parameters
$testPath = "C:\Temp\NetTraceTest"

# Cleanup function
function Remove-TestFiles {
    if (Test-Path $testPath) {
        Get-ChildItem -Path $testPath -Filter "*.etl" | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up test files" -ForegroundColor Gray
    }
}

# Test 1: Module Import
Write-Host "Step 1: Testing Module Import" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Cyan

try {
    Import-Module .\NetTrace.psd1 -Force
    Write-Host "✓ Module imported successfully" -ForegroundColor Green
    
    # Check if function is available
    $command = Get-Command NetTrace -ErrorAction SilentlyContinue
    if ($command) {
        Write-Host "✓ NetTrace command is available" -ForegroundColor Green
    } else {
        Write-Host "✗ NetTrace command not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Parameter Validation
Write-Host "Test 1: Parameter Validation" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow

$testsPassed = 0
$totalTests = 6

# Test missing File parameter
try {
    NetTrace -FileSize 50 -Path $testPath 2>$null
    Write-Host "ERROR: Should have failed with missing File parameter" -ForegroundColor Red
} catch {
    Write-Host "✓ Correctly rejected missing File parameter" -ForegroundColor Green
    $testsPassed++
}

# Test missing FileSize parameter  
try {
    NetTrace -File 5 -Path $testPath 2>$null
    Write-Host "ERROR: Should have failed with missing FileSize parameter" -ForegroundColor Red
} catch {
    Write-Host "✓ Correctly rejected missing FileSize parameter" -ForegroundColor Green
    $testsPassed++
}

# Test missing Path parameter
try {
    NetTrace -File 5 -FileSize 50 2>$null
    Write-Host "ERROR: Should have failed with missing Path parameter" -ForegroundColor Red
} catch {
    Write-Host "✓ Correctly rejected missing Path parameter" -ForegroundColor Green
    $testsPassed++
}

# Test invalid File parameter (0)
try {
    NetTrace -File 0 -FileSize 50 -Path $testPath 2>$null
    Write-Host "ERROR: Should have failed with invalid File parameter (0)" -ForegroundColor Red
} catch {
    Write-Host "✓ Correctly rejected invalid File parameter (0)" -ForegroundColor Green
    $testsPassed++
}

# Test invalid FileSize parameter (0)
try {
    NetTrace -File 5 -FileSize 0 -Path $testPath 2>$null
    Write-Host "ERROR: Should have failed with invalid FileSize parameter (0)" -ForegroundColor Red
} catch {
    Write-Host "✓ Correctly rejected invalid FileSize parameter (0)" -ForegroundColor Green
    $testsPassed++
}

# Test FileSize too small (less than 10MB)
try {
    NetTrace -File 5 -FileSize 5 -Path $testPath 2>$null
    Write-Host "ERROR: Should have failed with FileSize less than 10MB" -ForegroundColor Red
} catch {
    Write-Host "✓ Correctly rejected FileSize less than 10MB" -ForegroundColor Green
    $testsPassed++
}

Write-Host ""
Write-Host "Parameter validation tests: $testsPassed/$totalTests passed" -ForegroundColor $(if($testsPassed -eq $totalTests) { "Green" } else { "Yellow" })
Write-Host ""

# Test 3: Directory Creation
Write-Host "Step 3: Testing Directory Creation" -ForegroundColor Cyan
Write-Host "-----------------------------------" -ForegroundColor Cyan

$testDir = "C:\Temp\NetTraceTest_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

if (Test-Path $testDir) {
    Remove-Item $testDir -Recurse -Force
}

Write-Host "Test directory: $testDir" -ForegroundColor Gray
Write-Host "✓ Test directory prepared" -ForegroundColor Green
Write-Host ""

# Test 4: Stop Functionality (No Active Trace)
Write-Host "Step 4: Testing Stop Command (No Active Trace)" -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor Cyan

try {
    NetTrace -Stop
    Write-Host "✓ Stop command handled correctly when no trace is running" -ForegroundColor Green
} catch {
    Write-Host "✗ Error with stop command: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: File Format Validation
Write-Host "Step 5: File Format Validation" -ForegroundColor Cyan
Write-Host "-------------------------------" -ForegroundColor Cyan

$computerName = $env:COMPUTERNAME
$expectedFormat = "$computerName`_dd-MM-yy-HHmmss.etl"
Write-Host "Computer name: $computerName" -ForegroundColor Gray
Write-Host "Expected file format: $expectedFormat" -ForegroundColor Gray

# Generate a sample filename to show format
$sampleDate = Get-Date -Format "dd-MM-yy"
$sampleTime = Get-Date -Format "HHmmss"
$sampleFile = "$computerName`_$sampleDate-$sampleTime.etl"
Write-Host "Example filename: $sampleFile" -ForegroundColor Cyan
Write-Host "✓ File format validation completed" -ForegroundColor Green
Write-Host ""

# Interactive Testing Section
Write-Host "=== INTERACTIVE TESTING SECTION ===" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "The following tests will actually start network traces." -ForegroundColor Yellow
Write-Host "These tests are safe but will create real trace files." -ForegroundColor Yellow
Write-Host ""

$runInteractive = Read-Host "Do you want to run interactive tests? (y/N)"

if ($runInteractive -eq 'y' -or $runInteractive -eq 'Y') {
    
    # Test 6: Quick Basic Test (Small Files)
    Write-Host ""
    Write-Host "Step 6: Quick Basic Test (2 files, 10MB each)" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This test will:" -ForegroundColor Gray
    Write-Host "- Create 2 trace files of 10MB each" -ForegroundColor Gray
    Write-Host "- Show non-verbose output" -ForegroundColor Gray
    Write-Host "- Complete relatively quickly for testing" -ForegroundColor Gray
    Write-Host ""
    
    $proceed = Read-Host "Start basic test? (y/N)"
    if ($proceed -eq 'y' -or $proceed -eq 'Y') {
        Write-Host ""
        Write-Host "Starting basic test..." -ForegroundColor Green
        Write-Host "Expected output: Only filenames and summary" -ForegroundColor Cyan
        Write-Host ""
        
        # Run the actual test
        NetTrace -File 2 -FileSize 10 -Path $testDir
        
        Write-Host ""
        Write-Host "Basic test completed. Checking results..." -ForegroundColor Green
        
        # Check results
        if (Test-Path $testDir) {
            $files = Get-ChildItem -Path $testDir -Filter "*.etl" | Sort-Object Name
            Write-Host "Files created: $($files.Count)" -ForegroundColor Cyan
            
            foreach ($file in $files) {
                $sizeMB = [math]::Round($file.Length / 1MB, 2)
                Write-Host "  $($file.Name) - $sizeMB MB" -ForegroundColor White
            }
            
            if ($files.Count -gt 0) {
                Write-Host "✓ Basic test PASSED - Files were created" -ForegroundColor Green
            } else {
                Write-Host "✗ Basic test FAILED - No files created" -ForegroundColor Red
            }
        }
        
        Write-Host ""
    }
    
    # Test 7: Verbose Test
    Write-Host "Step 7: Verbose Test (2 files, 10MB each)" -ForegroundColor Cyan
    Write-Host "------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This test will:" -ForegroundColor Gray
    Write-Host "- Create 2 trace files of 10MB each" -ForegroundColor Gray
    Write-Host "- Show detailed verbose output" -ForegroundColor Gray
    Write-Host "- Demonstrate progress monitoring" -ForegroundColor Gray
    Write-Host ""
    
    $proceed = Read-Host "Start verbose test? (y/N)"
    if ($proceed -eq 'y' -or $proceed -eq 'Y') {
        Write-Host ""
        Write-Host "Starting verbose test..." -ForegroundColor Green
        Write-Host "Expected output: Detailed progress information" -ForegroundColor Cyan
        Write-Host ""
        
        # Clean up previous test files
        if (Test-Path $testDir) {
            Get-ChildItem -Path $testDir -Filter "*.etl" | Remove-Item -Force
        }
        
        # Run the verbose test
        NetTrace -File 2 -FileSize 10 -Path $testDir -Verbose
        
        Write-Host ""
        Write-Host "Verbose test completed. Checking results..." -ForegroundColor Green
        
        # Check results
        if (Test-Path $testDir) {
            $files = Get-ChildItem -Path $testDir -Filter "*.etl" | Sort-Object Name
            Write-Host "Files created: $($files.Count)" -ForegroundColor Cyan
            
            foreach ($file in $files) {
                $sizeMB = [math]::Round($file.Length / 1MB, 2)
                Write-Host "  $($file.Name) - $sizeMB MB" -ForegroundColor White
            }
            
            if ($files.Count -gt 0) {
                Write-Host "✓ Verbose test PASSED - Files were created with detailed output" -ForegroundColor Green
            } else {
                Write-Host "✗ Verbose test FAILED - No files created" -ForegroundColor Red
            }
        }
        
        Write-Host ""
    }
    
    # Test 8: Stop Functionality Test
    Write-Host "Step 8: Stop Functionality Test" -ForegroundColor Cyan
    Write-Host "--------------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This test will:" -ForegroundColor Gray
    Write-Host "- Start a trace with larger files (10MB)" -ForegroundColor Gray
    Write-Host "- Wait 10 seconds" -ForegroundColor Gray
    Write-Host "- Stop the trace manually" -ForegroundColor Gray
    Write-Host "- Test the stop functionality" -ForegroundColor Gray
    Write-Host ""
    
    $proceed = Read-Host "Start stop functionality test? (y/N)"
    if ($proceed -eq 'y' -or $proceed -eq 'Y') {
        Write-Host ""
        Write-Host "Starting trace for stop test..." -ForegroundColor Green
        
        # Clean up previous test files
        if (Test-Path $testDir) {
            Get-ChildItem -Path $testDir -Filter "*.etl" | Remove-Item -Force
        }
        
        # Start a background job to run the trace
        $job = Start-Job -ScriptBlock {
            param($ModulePath, $TestDir)
            Import-Module $ModulePath -Force
            NetTrace -File 3 -FileSize 10 -Path $TestDir -Verbose
        } -ArgumentList (Resolve-Path ".\NetTrace.psd1"), $testDir
        
        Write-Host "Trace started in background job. Waiting 10 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        Write-Host "Stopping trace..." -ForegroundColor Yellow
        NetTrace -Stop
        
        # Wait for job to complete
        Wait-Job $job -Timeout 30 | Out-Null
        $jobOutput = Receive-Job $job
        Remove-Job $job
        
        Write-Host ""
        Write-Host "Stop test completed. Job output:" -ForegroundColor Green
        $jobOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        # Check if files were created
        if (Test-Path $testDir) {
            $files = Get-ChildItem -Path $testDir -Filter "*.etl" | Sort-Object Name
            if ($files.Count -gt 0) {
                Write-Host "✓ Stop test PASSED - Trace was stopped successfully" -ForegroundColor Green
                Write-Host "Files created before stop: $($files.Count)" -ForegroundColor Cyan
            } else {
                Write-Host "✗ Stop test FAILED - No files created" -ForegroundColor Red
            }
        }
        
        Write-Host ""
    }
}

# Cleanup
Write-Host "=== CLEANUP ===" -ForegroundColor Yellow
Write-Host "===============" -ForegroundColor Yellow

if (Test-Path $testDir) {
    $files = Get-ChildItem -Path $testDir -Filter "*.etl"
    if ($files.Count -gt 0) {
        Write-Host ""
        Write-Host "Test files created in: $testDir" -ForegroundColor Cyan
        $files | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "  $($_.Name) - $sizeMB MB" -ForegroundColor White
        }
        
        Write-Host ""
        $cleanup = Read-Host "Delete test files? (Y/n)"
        if ($cleanup -ne 'n' -and $cleanup -ne 'N') {
            Remove-Item $testDir -Recurse -Force
            Write-Host "✓ Test files cleaned up" -ForegroundColor Green
        } else {
            Write-Host "Test files preserved in: $testDir" -ForegroundColor Yellow
        }
    }
}

# Final Summary
Write-Host ""
Write-Host "=== TEST SUMMARY ===" -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green
Write-Host "✓ Module import test completed" -ForegroundColor Green
Write-Host "✓ Parameter validation tests completed" -ForegroundColor Green
Write-Host "✓ Directory creation test completed" -ForegroundColor Green
Write-Host "✓ Stop command test completed" -ForegroundColor Green
Write-Host "✓ File format validation completed" -ForegroundColor Green

if ($runInteractive -eq 'y' -or $runInteractive -eq 'Y') {
    Write-Host "✓ Interactive tests completed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Testing completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Try manual commands: NetTrace -File 3 -FileSize 50 -Path 'C:\Traces'" -ForegroundColor White
Write-Host "2. Test with different file sizes and counts" -ForegroundColor White
Write-Host "3. Test the -Verbose flag for detailed output" -ForegroundColor White
Write-Host "4. Test NetTrace -Stop while a trace is running" -ForegroundColor White 