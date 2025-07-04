# NetTrace Module - Comprehensive Test Suite
# Version: 1.1.0
# Author: Naveed Khan
# Company: Hogwarts

# Script variables
$script:TestPath = "C:\NetTrace_Tests"
$script:StartTime = Get-Date

# Main menu function
function Show-Menu {
    Clear-Host
    Write-Host "NetTrace Module - Comprehensive Test Suite" -ForegroundColor Green
    Write-Host "Version: 1.1.0" -ForegroundColor Gray
    Write-Host "Author: Naveed Khan" -ForegroundColor Gray
    Write-Host "Company: Hogwarts" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Test Menu" -ForegroundColor Yellow
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
    Write-Host "Parameter Validation Test" -ForegroundColor Yellow
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
            Write-Host "Failed: $($test.Name) - Should have failed" -ForegroundColor Red
        } catch {
            Write-Host "Passed: $($test.Name) - Correctly rejected" -ForegroundColor Green
            $testsPassed++
        }
    }

    Write-Host ""
    Write-Host "Parameter validation results: $testsPassed/$totalTests passed" -ForegroundColor $(if($testsPassed -eq $totalTests) { "Green" } else { "Yellow" })
    Write-Host ""
}

function Test-Performance {
    Write-Host "Performance and Non-Blocking Test" -ForegroundColor Yellow
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
        Write-Host "Passed: Startup time: $([math]::Round($duration, 2)) seconds (Non-blocking)" -ForegroundColor Green
    } else {
        Write-Host "Warning: Startup time: $([math]::Round($duration, 2)) seconds (May be blocking)" -ForegroundColor Yellow
    }

    # Test 2: Console responsiveness
    Write-Host "Testing console responsiveness..." -ForegroundColor White
    $testStart = Get-Date
    Get-Date | Out-Null
    Get-Process | Select-Object -First 1 | Out-Null
    $testEnd = Get-Date
    $testDuration = ($testEnd - $testStart).TotalMilliseconds

    if ($testDuration -lt 1000) {
        Write-Host "Passed: Console response: $([math]::Round($testDuration)) ms (Responsive)" -ForegroundColor Green
    } else {
        Write-Host "Warning: Console response: $([math]::Round($testDuration)) ms (Slow)" -ForegroundColor Yellow
    }

    # Test 3: File creation
    Write-Host "Checking file creation..." -ForegroundColor White
    Start-Sleep -Seconds 3

    $logFiles = Get-ChildItem "$script:TestPath\NetTrace_*.log" -ErrorAction SilentlyContinue
    if ($logFiles) {
        Write-Host "Passed: Log file created: $($logFiles[0].Name)" -ForegroundColor Green
    } else {
        Write-Host "Failed: No log file found" -ForegroundColor Red
    }

    $etlFiles = Get-ChildItem "$script:TestPath\*.etl" -ErrorAction SilentlyContinue
    if ($etlFiles) {
        Write-Host "Passed: ETL file(s) created:" -ForegroundColor Green
        $etlFiles | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "   $($_.Name) ($sizeMB MB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "Warning: No ETL files found yet (may take a moment)" -ForegroundColor Yellow
    }

    # Test 4: Stop functionality
    Write-Host "Testing stop functionality..." -ForegroundColor White
    $stopStart = Get-Date
    NetTrace -Stop
    $stopEnd = Get-Date
    $stopDuration = ($stopEnd - $stopStart).TotalSeconds

    if ($stopDuration -lt 5) {
        Write-Host "Passed: Stop time: $([math]::Round($stopDuration, 2)) seconds" -ForegroundColor Green
    } else {
        Write-Host "Warning: Stop time: $([math]::Round($stopDuration, 2)) seconds (Slow)" -ForegroundColor Yellow
    }

    Write-Host ""
}

function Test-Quick {
    Write-Host "Quick Test" -ForegroundColor Yellow
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
        Write-Host "Passed: Quick test PASSED - Files created successfully" -ForegroundColor Green
        Write-Host "   ETL files: $($etlFiles.Count)" -ForegroundColor Gray
        Write-Host "   Log files: $($logFiles.Count)" -ForegroundColor Gray
    } else {
        Write-Host "Failed: Quick test FAILED - Files not created" -ForegroundColor Red
    }

    Write-Host "4. Stopping trace..." -ForegroundColor White
    NetTrace -Stop

    Write-Host ""
    Write-Host "Quick test completed!" -ForegroundColor Green
    Write-Host ""
}

function Test-Circular {
    Write-Host "Circular File Management Test" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This test demonstrates circular file management:" -ForegroundColor Cyan
    Write-Host "- Creates files up to the specified limit" -ForegroundColor Gray
    Write-Host "- Deletes oldest file when creating new ones" -ForegroundColor Gray
    Write-Host "- Maintains constant number of files" -ForegroundColor Gray
    Write-Host "- Runs until manually stopped" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Test configuration:" -ForegroundColor White
    Write-Host "- Max files: 2" -ForegroundColor Gray
    Write-Host "- File size: 10MB each" -ForegroundColor Gray
    Write-Host "- Path: $script:TestPath" -ForegroundColor Gray
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
    Write-Host "Standard Comprehensive Test" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Running comprehensive testing with multiple scenarios..." -ForegroundColor Cyan
    Write-Host ""

    # Test 1: Parameter validation
    Write-Host "Test 1: Parameter Validation" -ForegroundColor White
    Test-Parameters

    # Test 2: Performance testing
    Write-Host "Test 2: Performance and Responsiveness" -ForegroundColor White
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
        Write-Host "Passed: Verbose test completed" -ForegroundColor Green
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
            Write-Host "Passed: NetSh logging test PASSED - Log file created" -ForegroundColor Green
        } else {
            Write-Host "Failed: NetSh logging test FAILED - No log file found" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Standard test suite completed!" -ForegroundColor Green
    Write-Host ""
}

function Test-FullSuite {
    Write-Host "Full Test Suite" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Running all tests in sequence..." -ForegroundColor Cyan
    Write-Host "This will take approximately 15-20 minutes." -ForegroundColor Gray
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

    Write-Host "Running additional comprehensive tests..." -ForegroundColor Cyan

    # Test with different configurations
    $configs = @(
        @{ File = 3; FileSize = 15; Description = "3 files, 15MB each" },
        @{ File = 4; FileSize = 20; Description = "4 files, 20MB each" },
        @{ File = 2; FileSize = 50; Description = "2 files, 50MB each" }
    )

    foreach ($config in $configs) {
        Write-Host "Testing configuration: $($config.Description)" -ForegroundColor White

        if (Test-Path $script:TestPath) {
            Remove-Item $script:TestPath -Recurse -Force
        }
        New-Item -Path $script:TestPath -ItemType Directory -Force | Out-Null

        NetTrace -File $config.File -FileSize $config.FileSize -Path $script:TestPath
        Start-Sleep -Seconds 10
        NetTrace -Stop

        $etlFiles = Get-ChildItem "$script:TestPath\*.etl" -ErrorAction SilentlyContinue
        if ($etlFiles) {
            Write-Host "Passed: Configuration test - Files created" -ForegroundColor Green
        } else {
            Write-Host "Failed: Configuration test - No files created" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Full test suite completed!" -ForegroundColor Green
    Write-Host ""
}

# Main execution
function Main {
    # Check if running as Administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Error: This script must be run as Administrator!" -ForegroundColor Red
        Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }

    # Check if NetTrace module is available
    try {
        Get-Command NetTrace -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Error: NetTrace module not found!" -ForegroundColor Red
        Write-Host "Please ensure the NetTrace module is installed and imported." -ForegroundColor Yellow
        exit 1
    }

    # Main menu loop
    do {
        Show-Menu
        $choice = Read-Host "Enter your choice (0-6)"

        switch ($choice) {
            '1' { Test-Quick }
            '2' { Test-Standard }
            '3' { Test-Circular }
            '4' { Test-Parameters }
            '5' { Test-Performance }
            '6' { Test-FullSuite }
            '0' { 
                Write-Host "Exiting..." -ForegroundColor Green
                break
            }
            default { 
                Write-Host "Invalid choice. Please select 0-6." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }

        if ($choice -ne '0') {
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } while ($choice -ne '0')

    # Cleanup
    if (Test-Path $script:TestPath) {
        $cleanup = Read-Host "Delete test directory $script:TestPath? (y/N)"
        if ($cleanup -eq 'y' -or $cleanup -eq 'Y') {
            Remove-Item $script:TestPath -Recurse -Force
            Write-Host "Test directory cleaned up." -ForegroundColor Green
        }
    }
}

# Run the main function
Main 