@{
    RootModule = 'NetTrace.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'NetTrace Module'
    CompanyName = 'NetTrace'
    Copyright = '(c) 2024 NetTrace. All rights reserved.'
    Description = 'PowerShell module for Windows network tracing using netsh trace with automatic file rotation'
    PowerShellVersion = '5.1'
    RequiredModules = @()
    RequiredAssemblies = @()
    ScriptsToProcess = @()
    TypesToProcess = @()
    FormatsToProcess = @()
    NestedModules = @()
    FunctionsToExport = @('NetTrace')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    ModuleList = @()
    FileList = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Network', 'Tracing', 'Netsh', 'Windows', 'ETL')
            ProjectUri = ''
            LicenseUri = ''
            IconUri = ''
            ReleaseNotes = 'Simplified interface with automatic file rotation functionality'
            Prerelease = ''
            RequireLicenseAcceptance = $false
            ExternalModuleDependencies = @()
        }
    }
    HelpInfoURI = ''
    DefaultCommandPrefix = ''
} 