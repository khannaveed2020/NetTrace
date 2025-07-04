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

[CmdletBinding()]
param()

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "NetTrace Module - PowerShell Gallery Publication Validation" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$WarningCount = 0

function Write-ValidationResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Message = "",
        [bool]$IsWarning = $false
    )
    
    if ($Passed) {
        Write-Host "✅ $Test" -ForegroundColor Green
        if ($Message) {
            Write-Host "   $Message" -ForegroundColor Gray
        }
    } else {
        if ($IsWarning) {
            Write-Host "⚠️  $Test" -ForegroundColor Yellow
            $script:WarningCount++
        } else {
            Write-Host "❌ $Test" -ForegroundColor Red
            $script:ErrorCount++
        }
        if ($Message) {
            Write-Host "   $Message" -ForegroundColor Gray
        }
    }
}

# Test 1: Module Files Exist
Write-Host "📁 File Structure Validation" -ForegroundColor Yellow
Write-Host "-" * 40

$RequiredFiles = @(
    'NetTrace.psd1',
    'NetTrace.psm1', 
    'README.md',
    'LICENSE'
)

foreach ($File in $RequiredFiles) {
    $Exists = Test-Path $File
    Write-ValidationResult "Required file: $File" $Exists
}

# Test 2: Manifest Validation
Write-Host "`n🔍 Manifest Validation" -ForegroundColor Yellow
Write-Host "-" * 40

try {
    $Manifest = Test-ModuleManifest -Path ".\NetTrace.psd1" -ErrorAction Stop
    Write-ValidationResult "Manifest is valid" $true
    
    # Check version format
    $VersionValid = $Manifest.Version -match '^\d+\.\d+\.\d+$'
    Write-ValidationResult "Version format (SemVer)" $VersionValid "Version: $($Manifest.Version)"
    
    # Check required fields
    Write-ValidationResult "Author specified" (-not [string]::IsNullOrEmpty($Manifest.Author)) "Author: $($Manifest.Author)"
    Write-ValidationResult "Description specified" (-not [string]::IsNullOrEmpty($Manifest.Description)) "Length: $($Manifest.Description.Length) chars"
    Write-ValidationResult "Copyright specified" (-not [string]::IsNullOrEmpty($Manifest.Copyright)) "Copyright: $($Manifest.Copyright)"
    
    # Check PowerShell Gallery specific fields
    $PSData = $Manifest.PrivateData.PSData
    Write-ValidationResult "ProjectUri specified" (-not [string]::IsNullOrEmpty($PSData.ProjectUri)) "ProjectUri: $($PSData.ProjectUri)"
    Write-ValidationResult "LicenseUri specified" (-not [string]::IsNullOrEmpty($PSData.LicenseUri)) "LicenseUri: $($PSData.LicenseUri)"
    Write-ValidationResult "Tags specified" ($PSData.Tags.Count -gt 0) "Tags: $($PSData.Tags.Count) tags"
    Write-ValidationResult "ReleaseNotes specified" (-not [string]::IsNullOrEmpty($PSData.ReleaseNotes)) "Length: $($PSData.ReleaseNotes.Length) chars"
    
} catch {
    Write-ValidationResult "Manifest validation" $false $_.Exception.Message
}

# Test 3: Module Import Test
Write-Host "`n⚙️  Module Import Test" -ForegroundColor Yellow
Write-Host "-" * 40

try {
    # Remove if already loaded
    Remove-Module NetTrace -Force -ErrorAction SilentlyContinue
    
    # Import module
    Import-Module ".\NetTrace.psd1" -Force -ErrorAction Stop
    Write-ValidationResult "Module imports successfully" $true
    
    # Check exported functions
    $ExportedFunctions = Get-Command -Module NetTrace -CommandType Function
    Write-ValidationResult "Functions exported" ($ExportedFunctions.Count -gt 0) "Functions: $($ExportedFunctions.Name -join ', ')"
    
    # Check help availability
    $Help = Get-Help NetTrace -ErrorAction SilentlyContinue
    Write-ValidationResult "Help available" ($null -ne $Help) "Help sections: $($Help.PSObject.Properties.Name.Count)"
    
} catch {
    Write-ValidationResult "Module import" $false $_.Exception.Message
}

# Test 4: License Validation
Write-Host "`n📜 License Validation" -ForegroundColor Yellow
Write-Host "-" * 40

if (Test-Path "LICENSE") {
    $LicenseContent = Get-Content "LICENSE" -Raw
    Write-ValidationResult "LICENSE file exists" $true "Size: $($LicenseContent.Length) characters"
    
    $HasMITLicense = $LicenseContent -match "MIT License"
    Write-ValidationResult "MIT License detected" $HasMITLicense
    
    $HasCopyright = $LicenseContent -match "Copyright.*2025.*Naveed Khan"
    Write-ValidationResult "Copyright notice present" $HasCopyright
} else {
    Write-ValidationResult "LICENSE file exists" $false
}

# Test 5: README Validation
Write-Host "`n📖 Documentation Validation" -ForegroundColor Yellow
Write-Host "-" * 40

if (Test-Path "README.md") {
    $ReadmeContent = Get-Content "README.md" -Raw
    Write-ValidationResult "README.md exists" $true "Size: $($ReadmeContent.Length) characters"
    
    $HasInstallInstructions = $ReadmeContent -match "Install"
    Write-ValidationResult "Installation instructions" $HasInstallInstructions
    
    $HasExamples = $ReadmeContent -match "Example"
    Write-ValidationResult "Usage examples" $HasExamples
    
    $HasParameters = $ReadmeContent -match "Parameter"
    Write-ValidationResult "Parameter documentation" $HasParameters
} else {
    Write-ValidationResult "README.md exists" $false
}

# Test 6: Code Quality Checks
Write-Host "`n🔧 Code Quality Validation" -ForegroundColor Yellow
Write-Host "-" * 40

if (Test-Path "NetTrace.psm1") {
    $ModuleContent = Get-Content "NetTrace.psm1" -Raw
    
    # Check for proper error handling
    $HasTryCatch = $ModuleContent -match "try\s*{"
    Write-ValidationResult "Error handling (try-catch)" $HasTryCatch
    
    # Check for parameter validation
    $HasParameterValidation = $ModuleContent -match "\[Parameter\("
    Write-ValidationResult "Parameter validation" $HasParameterValidation
    
    # Check for help documentation
    $HasHelpBlocks = $ModuleContent -match "\.SYNOPSIS"
    Write-ValidationResult "Help documentation" $HasHelpBlocks
    
    # Check for requires statements
    $HasRequires = $ModuleContent -match "#Requires"
    Write-ValidationResult "Requirements specified" $HasRequires
}

# Test 7: PowerShell Gallery Compatibility
Write-Host "`n🌐 PowerShell Gallery Compatibility" -ForegroundColor Yellow
Write-Host "-" * 40

# Check PowerShell version compatibility
if ($Manifest) {
    $PSVersion = $Manifest.PowerShellVersion
    $CompatibleVersions = $Manifest.CompatiblePSEditions
    
    Write-ValidationResult "PowerShell version specified" (-not [string]::IsNullOrEmpty($PSVersion)) "Minimum: $PSVersion"
    Write-ValidationResult "Compatible editions specified" ($CompatibleVersions.Count -gt 0) "Editions: $($CompatibleVersions -join ', ')"
}

# Test 8: Security Checks
Write-Host "`n🔒 Security Validation" -ForegroundColor Yellow
Write-Host "-" * 40

# Check for admin requirements
$RequiresAdmin = $ModuleContent -match "#Requires -RunAsAdministrator"
Write-ValidationResult "Administrator requirements specified" $RequiresAdmin

# Check for no hardcoded credentials
$NoHardcodedCreds = -not ($ModuleContent -match "password\s*=|pwd\s*=|secret\s*=" -and $ModuleContent -notmatch "# Example")
Write-ValidationResult "No hardcoded credentials" $NoHardcodedCreds

# Test 9: Performance Considerations
Write-Host "`n⚡ Performance Validation" -ForegroundColor Yellow
Write-Host "-" * 40

# Check module size
$ModuleSize = (Get-ChildItem "NetTrace.psm1").Length
Write-ValidationResult "Module size reasonable" ($ModuleSize -lt 1MB) "Size: $([math]::Round($ModuleSize/1KB, 2)) KB"

# Test 10: Final Summary
Write-Host "`n📊 Validation Summary" -ForegroundColor Yellow
Write-Host "-" * 40

$TotalTests = $ErrorCount + $WarningCount + (Get-Variable -Name "script:*" -Scope Script | Where-Object { $_.Name -match "Count" }).Count
Write-Host "Total Issues Found: $ErrorCount errors, $WarningCount warnings" -ForegroundColor $(if ($ErrorCount -eq 0) { "Green" } else { "Red" })

if ($ErrorCount -eq 0) {
    Write-Host "`n🎉 MODULE IS READY FOR PUBLICATION!" -ForegroundColor Green
    Write-Host "✅ All critical requirements met" -ForegroundColor Green
    Write-Host "✅ PowerShell Gallery compatibility confirmed" -ForegroundColor Green
    Write-Host "✅ Code quality standards satisfied" -ForegroundColor Green
    
    if ($WarningCount -gt 0) {
        Write-Host "`n⚠️  $WarningCount warnings found - consider addressing for optimal quality" -ForegroundColor Yellow
    }
    
    Write-Host "`n📦 Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Run: Test-ScriptFileInfo (if using script publishing)" -ForegroundColor Gray
    Write-Host "2. Run: Publish-Module -Name NetTrace -Repository PSGallery -WhatIf" -ForegroundColor Gray
    Write-Host "3. Run: Publish-Module -Name NetTrace -Repository PSGallery -NuGetApiKey <your-api-key>" -ForegroundColor Gray
} else {
    Write-Host "`n❌ MODULE NOT READY FOR PUBLICATION" -ForegroundColor Red
    Write-Host "Please fix the $ErrorCount error(s) above before publishing" -ForegroundColor Red
}

Write-Host "`n" + "=" * 80 -ForegroundColor Cyan
Write-Host "Validation Complete" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan 