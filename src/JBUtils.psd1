@{
    RootModule           = 'JBUtils.psm1'
    ModuleVersion        = '1.10.2'
    GUID                 = 'de33eef4-1434-4420-a7f4-40fb4a6e7ee6'
    Author               = ''
    CompanyName          = ''
    Copyright            = ''
    Description          = 'A module with functions for various basic/low-level tasks.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @(
        'Desktop'
        'Core'
    )
    FunctionsToExport    = @()
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    RequiredModules      = @()
    PrivateData          = @{
        PSData = @{
            ReleaseNotes = 'Remove child variables for null overrides and preserve explicit empty values.'
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = ''
            Prerelease   = ''
            Tags         = @(
                'PSEdition_Desktop'
                'PSEdition_Core'
                'Windows'
            )
        }
    }
}
