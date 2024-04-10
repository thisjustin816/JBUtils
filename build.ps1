[CmdletBinding()]
param (
    [String]$Name = 'JBUtils',
    [String]$Version,
    [String]$SourceDirectory = "$PSScriptRoot/src",
    [String]$OutputDirectory = "$PSScriptRoot/out"
)

Remove-Item -Path $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
$ModuleOutputDirectory = "$OutputDirectory/$Name"
if ($Version) {
    $ModuleOutputDirectory += "/$Version"
}

Invoke-ScriptAnalyzer -Path $SourceDirectory -Recurse -Severity Information

New-Item -Path "$ModuleOutputDirectory/$name.psm1" -ItemType File -Force
$moduleNames = @()
$moduleContent = @()
Get-ChildItem -Path "$SourceDirectory/public" -Filter '*.ps1' -Exclude '*.Tests.ps1' -File -Recurse |
    ForEach-Object -Process {
        $moduleNames += $_.BaseName
        $moduleContent += ''
        $moduleContent += ( Get-Content -Path $_.FullName ).Replace('../private', 'private')
    }
$moduleContent | Set-Content -Path "$ModuleOutputDirectory/$name.psm1" -Force
New-Item -Path "$ModuleOutputDirectory/private" -ItemType Directory -Force
Get-ChildItem -Path "$SourceDirectory/private" -Exclude '*.Tests.ps1' |
    Copy-Item -Destination "$ModuleOutputDirectory/private" -Recurse -Force

Get-Module -Name $Name -All | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module -Name "$SourceDirectory/$name.psm1" -Force

$config = [PesterConfiguration]::Default
$config.Run.Path = $SourceDirectory
$config.Run.Exit = $true
$config.Run.Throw = $true
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
