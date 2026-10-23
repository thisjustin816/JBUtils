#Requires -Version 7.4
[CmdletBinding()]
param ()

$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
    Import-Module -FullyQualifiedName @{
        ModuleName = 'PSModuleUtils'; ModuleVersion = '5.0.0'; MaximumVersion = '5.999.999'
    } -ErrorAction Stop
    if (-not $env:GITHUB_ACTIONS) {
        Invoke-PSModuleAnalyzer -Fix
    }
    $builtManifest = Build-PSModule
    $testParameters = @{ Name = $builtManifest.BaseName }
    if ($env:GITHUB_ACTIONS -eq 'true') {
        $testParameters.ExcludeTag = 'HostIntegration'
    }
    Test-PSModule @testParameters
    $builtManifest
}
finally {
    Pop-Location
}
