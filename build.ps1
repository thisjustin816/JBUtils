Push-Location -Path $PSScriptRoot
Import-Module -Name 'PSModuleUtils' -MinimumVersion '2.1.0' -Force -ErrorAction Stop
if (-not $env:GITHUB_ACTIONS) {
    Invoke-PSModuleAnalyzer -Fix
}
$builtManifest = Build-PSModule
Test-PSModule -Name $builtManifest.BaseName
Pop-Location
$builtManifest
