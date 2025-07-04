#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates NetTrace module readiness for PowerShell Gallery publication
    
.DESCRIPTION
    Comprehensive validation script that checks all requirements for PowerShell Gallery publication
    including manifest validation, file structure, licensing, and functionality testing.
    
.EXAMPLE
    .\Validate-PublishReadiness.ps1
#>

# NetTrace Module - Publication Readiness Validation Script
# Version: 1.1.0
# Author: Naveed Khan
# Company: Hogwarts

# Initialize counters
$script:ErrorCount = 0
$script:WarningCount = 0

# Helper function to write validation results
function Write-ValidationResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Message = ""
    )

    if ($Passed) {
        Write-Host "PASS: $Test" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $Test" -ForegroundColor Red
        $script:ErrorCount++
    }
    if ($Message) {
        Write-Host "   $Message" -ForegroundColor Gray
    }
}

# Header
Write-Host "NetTrace Module - Publication Readiness Validation" -ForegroundColor Cyan
Write-Host "Version: 1.1.0" -ForegroundColor Gray
Write-Host "Author: Naveed Khan" -ForegroundColor Gray
Write-Host "Company: Hogwarts" -ForegroundColor Gray
Write-Host ""
Write-Host "Validating module for PowerShell Gallery publication..." -ForegroundColor Yellow
Write-Host ""

# Test 1: Module Files Exist
Write-Host "File Structure Validation" -ForegroundColor Yellow
Write-Host "-" * 40

$RequiredFiles = @(
    'NetTrace.psd1',
    'NetTrace.psm1',
    'README.md',
    'LICENSE'
)

foreach ($File in $RequiredFiles) {
    $Exists = Test-Path $File
    Write-ValidationResult -Test "Required file: $File" -Passed $Exists
}

# Test 2: Manifest Validation
Write-Host ""
Write-Host "Manifest Validation" -ForegroundColor Yellow
Write-Host "-" * 40

try {
    $Manifest = Test-ModuleManifest -Path ".\NetTrace.psd1" -ErrorAction Stop
    Write-ValidationResult -Test "Manifest is valid" -Passed $true

    # Check version format
    $VersionValid = $Manifest.Version -match '^\d+\.\d+\.\d+$'
    Write-ValidationResult -Test "Version format (SemVer)" -Passed $VersionValid -Message "Version: $($Manifest.Version)"

    # Check required fields
    Write-ValidationResult -Test "Author specified" -Passed (-not [string]::IsNullOrEmpty($Manifest.Author)) -Message "Author: $($Manifest.Author)"
    Write-ValidationResult -Test "Description specified" -Passed (-not [string]::IsNullOrEmpty($Manifest.Description)) -Message "Length: $($Manifest.Description.Length) chars"
    Write-ValidationResult -Test "Copyright specified" -Passed (-not [string]::IsNullOrEmpty($Manifest.Copyright)) -Message "Copyright: $($Manifest.Copyright)"

    # Check PowerShell Gallery specific fields
    $PSData = $Manifest.PrivateData.PSData
    Write-ValidationResult -Test "ProjectUri specified" -Passed (-not [string]::IsNullOrEmpty($PSData.ProjectUri)) -Message "ProjectUri: $($PSData.ProjectUri)"
    Write-ValidationResult -Test "LicenseUri specified" -Passed (-not [string]::IsNullOrEmpty($PSData.LicenseUri)) -Message "LicenseUri: $($PSData.LicenseUri)"
    Write-ValidationResult -Test "Tags specified" -Passed ($PSData.Tags.Count -gt 0) -Message "Tags: $($PSData.Tags.Count) tags"
    Write-ValidationResult -Test "ReleaseNotes specified" -Passed (-not [string]::IsNullOrEmpty($PSData.ReleaseNotes)) -Message "Length: $($PSData.ReleaseNotes.Length) chars"

} catch {
    Write-ValidationResult -Test "Manifest validation" -Passed $false -Message $_.Exception.Message
}

# Test 3: Module Import Test
Write-Host ""
Write-Host "Module Import Test" -ForegroundColor Yellow
Write-Host "-" * 40

try {
    # Remove if already loaded
    Remove-Module NetTrace -Force -ErrorAction SilentlyContinue

    # Import module
    Import-Module ".\NetTrace.psd1" -Force -ErrorAction Stop
    Write-ValidationResult -Test "Module imports successfully" -Passed $true

    # Check exported functions
    $ExportedFunctions = Get-Command -Module NetTrace -CommandType Function
    Write-ValidationResult -Test "Functions exported" -Passed ($ExportedFunctions.Count -gt 0) -Message "Functions: $($ExportedFunctions.Name -join ', ')"

    # Check help availability
    $Help = Get-Help NetTrace -ErrorAction SilentlyContinue
    Write-ValidationResult -Test "Help available" -Passed ($null -ne $Help) -Message "Help sections: $($Help.PSObject.Properties.Name.Count)"

} catch {
    Write-ValidationResult -Test "Module import" -Passed $false -Message $_.Exception.Message
}

# Test 4: License Validation
Write-Host ""
Write-Host "License Validation" -ForegroundColor Yellow
Write-Host "-" * 40

if (Test-Path "LICENSE") {
    $LicenseContent = Get-Content "LICENSE" -Raw
    Write-ValidationResult -Test "LICENSE file exists" -Passed $true -Message "Size: $($LicenseContent.Length) characters"

    $HasMITLicense = $LicenseContent -match "MIT License"
    Write-ValidationResult -Test "MIT License detected" -Passed $HasMITLicense

    $HasCopyright = $LicenseContent -match "Copyright.*2025.*Naveed Khan"
    Write-ValidationResult -Test "Copyright notice present" -Passed $HasCopyright
} else {
    Write-ValidationResult -Test "LICENSE file exists" -Passed $false
}

# Test 5: README Validation
Write-Host ""
Write-Host "Documentation Validation" -ForegroundColor Yellow
Write-Host "-" * 40

if (Test-Path "README.md") {
    $ReadmeContent = Get-Content "README.md" -Raw
    Write-ValidationResult -Test "README.md exists" -Passed $true -Message "Size: $($ReadmeContent.Length) characters"

    $HasInstallInstructions = $ReadmeContent -match "Install"
    Write-ValidationResult -Test "Installation instructions" -Passed $HasInstallInstructions

    $HasExamples = $ReadmeContent -match "Example"
    Write-ValidationResult -Test "Usage examples" -Passed $HasExamples

    $HasParameters = $ReadmeContent -match "Parameter"
    Write-ValidationResult -Test "Parameter documentation" -Passed $HasParameters
} else {
    Write-ValidationResult -Test "README.md exists" -Passed $false
}

# Test 6: Code Quality Checks
Write-Host ""
Write-Host "Code Quality Validation" -ForegroundColor Yellow
Write-Host "-" * 40

if (Test-Path "NetTrace.psm1") {
    $ModuleContent = Get-Content "NetTrace.psm1" -Raw

    # Check for proper error handling
    $HasTryCatch = $ModuleContent -match "try\s*{"
    Write-ValidationResult -Test "Error handling (try-catch)" -Passed $HasTryCatch

    # Check for parameter validation
    $HasParameterValidation = $ModuleContent -match "\[Parameter\("
    Write-ValidationResult -Test "Parameter validation" -Passed $HasParameterValidation

    # Check for help documentation
    $HasHelpBlocks = $ModuleContent -match "\.SYNOPSIS"
    Write-ValidationResult -Test "Help documentation" -Passed $HasHelpBlocks

    # Check for requires statements
    $HasRequires = $ModuleContent -match "#Requires"
    Write-ValidationResult -Test "Requirements specified" -Passed $HasRequires
}

# Test 7: PowerShell Gallery Compatibility
Write-Host ""
Write-Host "PowerShell Gallery Compatibility" -ForegroundColor Yellow
Write-Host "-" * 40

# Check PowerShell version compatibility
if ($Manifest) {
    $PSVersion = $Manifest.PowerShellVersion
    $CompatibleVersions = $Manifest.CompatiblePSEditions

    Write-ValidationResult -Test "PowerShell version specified" -Passed (-not [string]::IsNullOrEmpty($PSVersion)) -Message "Minimum: $PSVersion"
    Write-ValidationResult -Test "Compatible editions specified" -Passed ($CompatibleVersions.Count -gt 0) -Message "Editions: $($CompatibleVersions -join ', ')"
}

# Test 8: Security Checks
Write-Host ""
Write-Host "Security Validation" -ForegroundColor Yellow
Write-Host "-" * 40

# Check for admin requirements
$RequiresAdmin = $ModuleContent -match "#Requires -RunAsAdministrator"
Write-ValidationResult -Test "Administrator requirements specified" -Passed $RequiresAdmin

# Check for no hardcoded credentials
$NoHardcodedCreds = -not ($ModuleContent -match "password\s*=|pwd\s*=|secret\s*=" -and $ModuleContent -notmatch "# Example")
Write-ValidationResult -Test "No hardcoded credentials" -Passed $NoHardcodedCreds

# Test 9: Performance Considerations
Write-Host ""
Write-Host "Performance Validation" -ForegroundColor Yellow
Write-Host "-" * 40

# Check module size
$ModuleSize = (Get-ChildItem "NetTrace.psm1").Length
Write-ValidationResult -Test "Module size reasonable" -Passed ($ModuleSize -lt 1MB) -Message "Size: $([math]::Round($ModuleSize/1KB, 2)) KB"

# Test 10: Final Summary
Write-Host ""
Write-Host "Validation Summary" -ForegroundColor Yellow
Write-Host "-" * 40

Write-Host "Total Issues Found: $ErrorCount errors, $WarningCount warnings" -ForegroundColor $(if ($ErrorCount -eq 0) { "Green" } else { "Red" })

if ($ErrorCount -eq 0) {
    Write-Host ""
    Write-Host "MODULE IS READY FOR PUBLICATION!" -ForegroundColor Green
    Write-Host "All critical requirements met" -ForegroundColor Green
    Write-Host "PowerShell Gallery compatibility confirmed" -ForegroundColor Green
    Write-Host "Code quality standards satisfied" -ForegroundColor Green

    if ($WarningCount -gt 0) {
        Write-Host ""
        Write-Host "$WarningCount warnings found - consider addressing for optimal quality" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Run: Test-ScriptFileInfo (if using script publishing)" -ForegroundColor Gray
    Write-Host "2. Run: Publish-Module -Name NetTrace -Repository PSGallery -WhatIf" -ForegroundColor Gray
    Write-Host "3. Run: Publish-Module -Name NetTrace -Repository PSGallery -NuGetApiKey <your-api-key>" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "MODULE NOT READY FOR PUBLICATION" -ForegroundColor Red
    Write-Host "Please fix the $ErrorCount error(s) above before publishing" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Validation Complete" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan 