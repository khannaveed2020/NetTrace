@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'NetTrace.psm1'

    # Version number of this module.
    ModuleVersion = '1.3.0'

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
            ReleaseNotes = 'v1.3.0: COMPREHENSIVE SERVICE ARCHITECTURE FIX - Complete overhaul of NSSM service implementation with critical reliability improvements: 1) Fixed NSSM installation to use persistent location ($env:ProgramData\NetTrace\NSSM) instead of temporary directory that could be cleaned up, 2) Implemented simplified batch file wrapper approach to eliminate complex PowerShell parameter escaping issues that caused service configuration failures, 3) Enhanced service validation with comprehensive pre-start checks for wrapper files, service scripts, and NSSM availability, 4) Added detailed service startup monitoring with extended wait times and better error diagnostics, 5) Improved error handling and logging throughout the service lifecycle, 6) Added automatic wrapper recreation if missing during service start, 7) Enhanced status reporting to show validation information for all service components. This addresses the fundamental architectural issues that prevented reliable NSSM service operation and provides a robust, production-ready Windows Service implementation.'
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
