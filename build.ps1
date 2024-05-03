#Requires -Modules PSModuleUtils

$BuildPSModule = @{
    Name        = 'JBUtils'
    Version     = '0.0.2'
    Description = 'A module of basic/low-level PowerShell functions.'
    Tags        = ('PSEdition_Desktop', 'PSEdition_Core', 'Windows')
}

Push-Location -Path $PSScriptRoot
Import-Module -Name "$PSScriptRoot/src/$($BuildPSModule['Name']).psm1" -Force
Build-PSModule @BuildPSModule
Test-PSModule -Name $BuildPSModule['Name']
Pop-Location
