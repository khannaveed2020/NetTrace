#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Comprehensive NetTrace Module Testing Suite
    
.DESCRIPTION
    Complete testing suite for the NetTrace module with interactive prompts for different test types.
    Combines functionality from all individual test scripts into one comprehensive tool.
    
.NOTES
    File Name      : Test-NetTrace-Complete.ps1
    Version        : 1.0.0
    Author         : Naveed Khan
    Requires       : Administrator privileges
    Compatibility  : PowerShell 5.1 and PowerShell 7+
#>

# Test configuration
$script:TestPath = "C:\Traces\NetTraceTest"
$script:ModulePath = ".\NetTrace.psd1"

function Show-Welcome {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                NetTrace Module Testing Suite                 ║" -ForegroundColor Cyan
    Write-Host "║                     Version 1.0.0                           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This comprehensive testing suite validates all NetTrace functionality:" -ForegroundColor White
    Write-Host "• Module import and parameter validation" -ForegroundColor Gray
    Write-Host "• Non-blocking operation and console responsiveness" -ForegroundColor Gray
    Write-Host "• File creation, rotation, and circular management" -ForegroundColor Gray
    Write-Host "• Stop functionality and cleanup operations" -ForegroundColor Gray
    Write-Host "• Performance and reliability testing" -ForegroundColor Gray
    Write-Host ""
}

function Test-Prerequisites {
    Write-Host "═══ Prerequisites Check ═══" -ForegroundColor Yellow
    
    # Check Administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (-not $isAdmin) {
        Write-Host "❌ ERROR: Administrator privileges required!" -ForegroundColor Red
        Write-Host ""
        Write-Host "To run NetTrace tests:" -ForegroundColor Cyan
        Write-Host "1. Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor White
        Write-Host "2. Navigate to: $PWD" -ForegroundColor White
        Write-Host "3. Run this script again" -ForegroundColor White
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    Write-Host "✅ Administrator privileges confirmed" -ForegroundColor Green
    
    # Check module file exists
    if (!(Test-Path $script:ModulePath)) {
        Write-Host "❌ ERROR: NetTrace module not found at $script:ModulePath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ NetTrace module file found" -ForegroundColor Green
    
    # Import module
    try {
        Remove-Module NetTrace -Force -ErrorAction SilentlyContinue
        Import-Module $script:ModulePath -Force
        Write-Host "✅ NetTrace module imported successfully" -ForegroundColor Green
        
        # Verify command is available
        $command = Get-Command NetTrace -ErrorAction SilentlyContinue
        if ($command) {
            Write-Host "✅ NetTrace command is available" -ForegroundColor Green
        } else {
            throw "NetTrace command not found after import"
        }
    } catch {
        Write-Host "❌ ERROR: Failed to import module - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
}

function Show-TestMenu {
    Write-Host "═══ Test Menu ═══" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Choose your testing approach:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Quick Test" -ForegroundColor White -NoNewline
    Write-Host "           - Fast validation of core functionality (2-3 minutes)" -ForegroundColor Gray
    Write-Host "2. Standard Test" -ForegroundColor White -NoNewline
    Write-Host "       - Comprehensive testing with user interaction (5-10 minutes)" -ForegroundColor Gray
    Write-Host "3. Circular Test" -ForegroundColor White -NoNewline
    Write-Host "       - Test circular file management behavior (manual stop)" -ForegroundColor Gray
    Write-Host "4. Parameter Test" -ForegroundColor White -NoNewline
    Write-Host "      - Validate parameter validation and error handling" -ForegroundColor Gray
    Write-Host "5. Performance Test" -ForegroundColor White -NoNewline
    Write-Host "    - Test non-blocking behavior and responsiveness" -ForegroundColor Gray
    Write-Host "6. Full Test Suite" -ForegroundColor White -NoNewline
    Write-Host "     - Run all tests in sequence (15-20 minutes)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "0. Exit" -ForegroundColor Red
    Write-Host ""
}

function Test-Parameters {
    Write-Host "═══ Parameter Validation Test ═══" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Testing parameter validation and error handling..." -ForegroundColor Cyan
    
    $testsPassed = 0
    $totalTests = 6
    
    # Test cases with expected failures
    $testCases = @(
        @{ Name = "Missing File parameter"; Params = @{ FileSize = 50; Path = $script:TestPath } },
        @{ Name = "Missing FileSize parameter"; Params = @{ File = 5; Path = $script:TestPath } },
        @{ Name = "Missing Path parameter"; Params = @{ File = 5; FileSize = 50 } },
        @{ Name = "Invalid File parameter (0)"; Params = @{ File = 0; FileSize = 50; Path = $script:TestPath } },
        @{ Name = "Invalid FileSize parameter (0)"; Params = @{ File = 5; FileSize = 0; Path = $script:TestPath } },
        @{ Name = "FileSize too small (5MB)"; Params = @{ File = 5; FileSize = 5; Path = $script:TestPath } }
    )
    
    foreach ($test in $testCases) {
        try {
            NetTrace @($test.Params) -ErrorAction Stop 2>$null
            Write-Host "❌ $($test.Name): Should have failed" -ForegroundColor Red
        } catch {
            Write-Host "✅ $($test.Name): Correctly rejected" -ForegroundColor Green
            $testsPassed++
        }
    }
    
    Write-Host ""
    Write-Host "Parameter validation results: $testsPassed/$totalTests passed" -ForegroundColor $(if($testsPassed -eq $totalTests) { "Green" } else { "Yellow" })
    Write-Host ""
}

function Test-Performance {
    Write-Host "═══ Performance & Non-Blocking Test ═══" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Testing startup performance and console responsiveness..." -ForegroundColor Cyan
    
    # Prepare test directory
    if (Test-Path $script:TestPath) {
        Remove-Item $script:TestPath -Recurse -Force
    }
    New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null
    
    # Test 1: Startup time
    Write-Host "Testing startup time..." -ForegroundColor White
    $startTime = Get-Date
    NetTrace -File 2 -FileSize 10 -Path $script:TestPath
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    if ($duration -lt 2) {
        Write-Host "✅ Startup time: $([math]::Round($duration, 2)) seconds (Non-blocking)" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Startup time: $([math]::Round($duration, 2)) seconds (May be blocking)" -ForegroundColor Yellow
    }
    
    # Test 2: Console responsiveness
    Write-Host "Testing console responsiveness..." -ForegroundColor White
    $testStart = Get-Date
    Get-Date | Out-Null
    Get-Process | Select-Object -First 1 | Out-Null
    $testEnd = Get-Date
    $testDuration = ($testEnd - $testStart).TotalMilliseconds
    
    if ($testDuration -lt 1000) {
        Write-Host "✅ Console response: $([math]::Round($testDuration)) ms (Responsive)" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Console response: $([math]::Round($testDuration)) ms (Slow)" -ForegroundColor Yellow
    }
    
    # Test 3: File creation
    Write-Host "Checking file creation..." -ForegroundColor White
    Start-Sleep -Seconds 3
    
    $logFiles = Get-ChildItem "$script:TestPath\NetTrace_*.log" -ErrorAction SilentlyContinue
    if ($logFiles) {
        Write-Host "✅ Log file created: $($logFiles[0].Name)" -ForegroundColor Green
    } else {
        Write-Host "❌ No log file found" -ForegroundColor Red
    }
    
    $etlFiles = Get-ChildItem "$script:TestPath\*.etl" -ErrorAction SilentlyContinue
    if ($etlFiles) {
        Write-Host "✅ ETL file(s) created:" -ForegroundColor Green
        $etlFiles | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "   $($_.Name) ($sizeMB MB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "⚠️ No ETL files found yet (may take a moment)" -ForegroundColor Yellow
    }
    
    # Test 4: Stop functionality
    Write-Host "Testing stop functionality..." -ForegroundColor White
    $stopStart = Get-Date
    NetTrace -Stop
    $stopEnd = Get-Date
    $stopDuration = ($stopEnd - $stopStart).TotalSeconds
    
    if ($stopDuration -lt 5) {
        Write-Host "✅ Stop time: $([math]::Round($stopDuration, 2)) seconds" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Stop time: $([math]::Round($stopDuration, 2)) seconds (Slow)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Test-Quick {
    Write-Host "═══ Quick Test ═══" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Running quick validation of core functionality..." -ForegroundColor Cyan
    Write-Host ""
    
    # Prepare test directory
    if (Test-Path $script:TestPath) {
        Remove-Item $script:TestPath -Recurse -Force
    }
    New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null
    
    Write-Host "1. Starting NetTrace..." -ForegroundColor White
    NetTrace -File 2 -FileSize 10 -Path $script:TestPath
    
    Write-Host "2. Waiting for file creation..." -ForegroundColor White
    Start-Sleep -Seconds 5
    
    Write-Host "3. Checking results..." -ForegroundColor White
    $etlFiles = Get-ChildItem "$script:TestPath\*.etl" -ErrorAction SilentlyContinue
    $logFiles = Get-ChildItem "$script:TestPath\NetTrace_*.log" -ErrorAction SilentlyContinue
    
    if ($etlFiles -and $logFiles) {
        Write-Host "✅ Quick test PASSED - Files created successfully" -ForegroundColor Green
        Write-Host "   ETL files: $($etlFiles.Count)" -ForegroundColor Gray
        Write-Host "   Log files: $($logFiles.Count)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Quick test FAILED - Files not created" -ForegroundColor Red
    }
    
    Write-Host "4. Stopping trace..." -ForegroundColor White
    NetTrace -Stop
    
    Write-Host ""
    Write-Host "Quick test completed!" -ForegroundColor Green
    Write-Host ""
}

function Test-Circular {
    Write-Host "═══ Circular File Management Test ═══" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This test demonstrates circular file management:" -ForegroundColor Cyan
    Write-Host "• Creates files up to the specified limit" -ForegroundColor Gray
    Write-Host "• Deletes oldest file when creating new ones" -ForegroundColor Gray
    Write-Host "• Maintains constant number of files" -ForegroundColor Gray
    Write-Host "• Runs until manually stopped" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Test configuration:" -ForegroundColor White
    Write-Host "• Max files: 2" -ForegroundColor Gray
    Write-Host "• File size: 10MB each" -ForegroundColor Gray
    Write-Host "• Path: $script:TestPath" -ForegroundColor Gray
    Write-Host ""
    
    $proceed = Read-Host "Start circular management test? (y/N)"
    
    if ($proceed -eq 'y' -or $proceed -eq 'Y') {
        # Prepare test directory
        if (Test-Path $script:TestPath) {
            Remove-Item $script:TestPath -Recurse -Force
        }
        New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null
        
        Write-Host ""
        Write-Host "Starting circular test..." -ForegroundColor Green
        Write-Host "Watch for 'Removed oldest file' messages!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To stop the test:" -ForegroundColor Cyan
        Write-Host "1. Open another Administrator PowerShell window" -ForegroundColor White
        Write-Host "2. Navigate to this directory" -ForegroundColor White
        Write-Host "3. Run: NetTrace -Stop" -ForegroundColor White
        Write-Host ""
        
        # Start the test with verbose output
        NetTrace -File 2 -FileSize 10 -Path $script:TestPath -Verbose
        
        Write-Host ""
        Write-Host "Circular test completed." -ForegroundColor Green
    } else {
        Write-Host "Circular test cancelled." -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Test-Standard {
    Write-Host "═══ Standard Comprehensive Test ═══" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Running comprehensive testing with multiple scenarios..." -ForegroundColor Cyan
    Write-Host ""
    
    # Test 1: Parameter validation
    Write-Host "Test 1: Parameter Validation" -ForegroundColor White
    Test-Parameters
    
    # Test 2: Performance testing
    Write-Host "Test 2: Performance & Responsiveness" -ForegroundColor White
    Test-Performance
    
    # Test 3: Verbose mode
    Write-Host "Test 3: Verbose Mode" -ForegroundColor White
    Write-Host "Testing verbose output mode..." -ForegroundColor Cyan
    
    $testVerbose = Read-Host "Run verbose mode test? (y/N)"
    if ($testVerbose -eq 'y' -or $testVerbose -eq 'Y') {
        if (Test-Path $script:TestPath) {
            Remove-Item $script:TestPath -Recurse -Force
        }
        New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null
        
        Write-Host "Starting verbose test..." -ForegroundColor Green
        NetTrace -File 2 -FileSize 10 -Path $script:TestPath -Verbose
        
        Start-Sleep -Seconds 5
        NetTrace -Stop
        Write-Host "✅ Verbose test completed" -ForegroundColor Green
    }
    
    # Test 4: NetSh logging
    Write-Host ""
    Write-Host "Test 4: NetSh Output Logging" -ForegroundColor White
    $testLogging = Read-Host "Test NetSh output logging? (y/N)"
    if ($testLogging -eq 'y' -or $testLogging -eq 'Y') {
        if (Test-Path $script:TestPath) {
            Remove-Item $script:TestPath -Recurse -Force
        }
        New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null
        
        Write-Host "Starting NetSh logging test..." -ForegroundColor Green
        NetTrace -File 2 -FileSize 10 -Path $script:TestPath -LogNetshOutput
        
        Start-Sleep -Seconds 5
        NetTrace -Stop
        
        $netshLog = Get-ChildItem "$script:TestPath\netsh_trace.log" -ErrorAction SilentlyContinue
        if ($netshLog) {
            Write-Host "✅ NetSh logging test PASSED - Log file created" -ForegroundColor Green
        } else {
            Write-Host "❌ NetSh logging test FAILED - No log file found" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Standard test suite completed!" -ForegroundColor Green
    Write-Host ""
}

function Test-FullSuite {
    Write-Host "═══ Full Test Suite ═══" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Running complete test suite (all tests)..." -ForegroundColor Cyan
    Write-Host "This will take 15-20 minutes to complete." -ForegroundColor Yellow
    Write-Host ""
    
    $proceed = Read-Host "Continue with full test suite? (y/N)"
    if ($proceed -ne 'y' -and $proceed -ne 'Y') {
        Write-Host "Full test suite cancelled." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "Starting full test suite..." -ForegroundColor Green
    Write-Host ""
    
    # Run all tests
    Test-Parameters
    Test-Performance
    Test-Quick
    
    Write-Host "Running verbose mode test..." -ForegroundColor White
    if (Test-Path $script:TestPath) {
        Remove-Item $script:TestPath -Recurse -Force
    }
    New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null
    NetTrace -File 2 -FileSize 10 -Path $script:TestPath -Verbose
    Start-Sleep -Seconds 10
    NetTrace -Stop
    
    Write-Host ""
    Write-Host "═══ Full Test Suite Completed ═══" -ForegroundColor Green
    Write-Host ""
}

function Show-Results {
    param([string]$TestType)
    
    Write-Host "═══ Test Results Summary ═══" -ForegroundColor Green
    Write-Host ""
    Write-Host "Test type: $TestType" -ForegroundColor Cyan
    Write-Host "Test path: $script:TestPath" -ForegroundColor Gray
    Write-Host ""
    
    if (Test-Path $script:TestPath) {
        $etlFiles = Get-ChildItem "$script:TestPath\*.etl" -ErrorAction SilentlyContinue
        $logFiles = Get-ChildItem "$script:TestPath\NetTrace_*.log" -ErrorAction SilentlyContinue
        $netshLogs = Get-ChildItem "$script:TestPath\netsh_trace.log" -ErrorAction SilentlyContinue
        
        Write-Host "Files created:" -ForegroundColor White
        Write-Host "• ETL files: $($etlFiles.Count)" -ForegroundColor Gray
        Write-Host "• Log files: $($logFiles.Count)" -ForegroundColor Gray
        Write-Host "• NetSh logs: $($netshLogs.Count)" -ForegroundColor Gray
        
        if ($etlFiles) {
            Write-Host ""
            Write-Host "ETL files details:" -ForegroundColor White
            $etlFiles | ForEach-Object {
                $sizeMB = [math]::Round($_.Length / 1MB, 2)
                Write-Host "  $($_.Name) - $sizeMB MB" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "No test files found." -ForegroundColor Yellow
    }
    
    Write-Host ""
    $cleanup = Read-Host "Clean up test files? (Y/n)"
    if ($cleanup -ne 'n' -and $cleanup -ne 'N') {
        if (Test-Path $script:TestPath) {
            Remove-Item $script:TestPath -Recurse -Force
            Write-Host "✅ Test files cleaned up" -ForegroundColor Green
        }
    } else {
        Write-Host "Test files preserved in: $script:TestPath" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Main execution
try {
    Show-Welcome
    Test-Prerequisites
    
    do {
        Show-TestMenu
        $choice = Read-Host "Select test option (0-6)"
        Write-Host ""
        
        switch ($choice) {
            "1" { 
                Test-Quick
                Show-Results "Quick Test"
            }
            "2" { 
                Test-Standard
                Show-Results "Standard Test"
            }
            "3" { 
                Test-Circular
                Show-Results "Circular Test"
            }
            "4" { 
                Test-Parameters
                Show-Results "Parameter Test"
            }
            "5" { 
                Test-Performance
                Show-Results "Performance Test"
            }
            "6" { 
                Test-FullSuite
                Show-Results "Full Test Suite"
            }
            "0" { 
                Write-Host "Exiting NetTrace Testing Suite..." -ForegroundColor Yellow
                break
            }
            default { 
                Write-Host "Invalid selection. Please choose 0-6." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        
        if ($choice -ne "0") {
            Write-Host ""
            Read-Host "Press Enter to return to main menu"
        }
        
    } while ($choice -ne "0")
    
} catch {
    Write-Host ""
    Write-Host "❌ Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
} 