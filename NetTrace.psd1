@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'NetTrace.psm1'

    # Version number of this module.
    ModuleVersion = '1.1.0'

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
    Description = 'PowerShell module for Windows network tracing using netsh trace with automatic circular file rotation and background monitoring. Features include configurable file size limits, circular buffer management, non-blocking operation, optional activity logging, technical diagnostics, and administrator privilege validation.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    DotNetFrameworkVersion = '4.7.2'

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
    FunctionsToExport = @('NetTrace')

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
        'README.md',
        'LICENSE'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Network', 'Tracing', 'Netsh', 'Windows', 'ETL', 'Monitoring', 'Diagnostics', 'Performance', 'Troubleshooting', 'Admin')
            LicenseUri = 'https://github.com/khannaveed2020/NetTrace/blob/main/LICENSE'
            ProjectUri = 'https://github.com/khannaveed2020/NetTrace'
            ReleaseNotes = 'v1.1.0: Added optional logging functionality with -Log parameter for enhanced control over disk I/O and performance. Fixed file counter accuracy issues and improved stop command reliability. Consolidated test suite and enhanced documentation.'
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
