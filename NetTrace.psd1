@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'NetTrace.psm1'

    # Version number of this module.
    ModuleVersion = '1.2.11'

    # Supported PSEditions
    CompatiblePSEditions = @('Core', 'Desktop')

    # ID used to uniquely identify this module
    GUID = 'c8fe6e2e-8245-44e7-ae87-cf9a44e882f6'

    # Author of this module
    Author = 'Naveed Khan'

    # Company or vendor of this module
    CompanyName = 'Hogwarts'

    # Copyright statement for this module
    Copyright = '(c) 2025 Naveed Khan. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module for Windows network tracing using netsh trace with automatic circular file rotation and background monitoring. Features include configurable file size limits, circular buffer management, non-blocking operation, optional activity logging, technical diagnostics, administrator privilege validation, and true Windows Service persistence that survives user logouts and system reboots.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    DotNetFrameworkVersion = '4.6.1'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion = '4.0'

    # Processor architecture (None, X86, Amd64) required by this module
    ProcessorArchitecture = 'None'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()

    # Functions to export from this module
    FunctionsToExport = @('NetTrace', 'Get-NetTraceStatus')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = @()

    # DSC resources to export from this module
    DscResourcesToExport = @()

    # List of all modules packaged with this module
    ModuleList = @()

    # List of all files packaged with this module
    FileList = @(
        'NetTrace.psm1',
        'NetTrace.psd1',
        'NetTrace-Service.ps1',
        'NetTrace-ServiceRunner.ps1',
        'README.md',
        'LICENSE'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Network', 'Tracing', 'Netsh', 'Windows', 'ETL', 'Monitoring', 'Diagnostics', 'Performance', 'Troubleshooting', 'Admin')
            LicenseUri = 'https://github.com/khannaveed2020/NetTrace/blob/main/LICENSE'
            ProjectUri = 'https://github.com/khannaveed2020/NetTrace'
            ReleaseNotes = 'v1.2.11: CRITICAL SERVICE FIX - Fixed service configuration to force update parameters and ensure correct version path. Windows Service now properly reconfigures with current module version path instead of using cached old version. v1.2.10: CRITICAL VERSION FIX - Fixed service configuration to use correct module version path. Windows Service now uses fresh short path names for current module version instead of cached old version paths. v1.2.9: CRITICAL PATH FIX - Fixed service path quoting issue by using 8.3 short path names to avoid spaces in "Program Files". Windows Service now executes scripts correctly without path parsing errors. v1.2.8: CRITICAL NSSM FIX - Fixed NSSM service configuration by changing Parameters to AppParameters. Windows Service installation now works correctly. v1.2.7: CRITICAL SYNTAX FIX - Fixed PowerShell syntax errors in NetTrace-ServiceRunner.ps1 that prevented the persistence feature from working. Removed malformed try-catch blocks with extra closing braces that caused parsing failures. The persistence feature now works correctly with proper Windows Service implementation. Previous v1.2.6 was non-functional due to syntax errors. v1.2.6: CRITICAL ARCHITECTURAL FIX - Fixed persistence to use true Windows Service execution instead of session-dependent processes. v1.2.5: Added basic persistence feature for long-running captures. v1.2.4: Improved user experience and admin privilege handling. v1.2.3: Fixed PowerShell Gallery package to include missing service script files. v1.2.2: Implemented true Windows Service persistence using NSSM. v1.2.1: Implemented service-based persistence architecture. v1.2.0: Added persistence feature using native netsh trace persistent=yes parameter. v1.1.1: Removed #Requires -RunAsAdministrator directive to allow module loading in non-admin sessions. v1.1.0: Added optional logging functionality, fixed file counter accuracy, improved stop command reliability.'
            Prerelease = ''
            RequireLicenseAcceptance = $false
            ExternalModuleDependencies = @()
            IconUri = ''
            ReadMeUri = 'https://github.com/khannaveed2020/NetTrace/blob/main/README.md'
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI = 'https://github.com/khannaveed2020/NetTrace/issues'
}
