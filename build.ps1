$BuildPSModule = @{
    Name        = 'JBUtils'
    Version     = '1.0.6'
    Description = 'A module with functions for various basic/low-level tasks.'
    Tags        = ('PSEdition_Desktop', 'PSEdition_Core', 'Windows')
}

Push-Location -Path $PSScriptRoot
Import-Module -Name "$PSScriptRoot/src/$($BuildPSModule['Name']).psm1" -Force
Install-Module -Name PSModuleUtils -Force
if (!$env:GITHUB_ACTIONS) {
    Invoke-PSModuleAnalyzer -Fix
}
Build-PSModule @BuildPSModule
Test-PSModule -Name $BuildPSModule['Name']
Pop-Location
