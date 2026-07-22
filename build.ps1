$BuildPSModule = @{
    Name    = 'JBUtils'
    Version = '1.3.0'
}

Push-Location -Path $PSScriptRoot
Import-Module -Name 'PSModuleUtils' -MinimumVersion '2.0.0' -Force -ErrorAction Stop
if (-not $env:GITHUB_ACTIONS) {
    Invoke-PSModuleAnalyzer -Fix
}
Build-PSModule @BuildPSModule
Test-PSModule -Name $BuildPSModule['Name']
Pop-Location
