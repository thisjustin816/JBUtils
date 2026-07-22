<#
.SYNOPSIS
Installs NuGet CLI.

.DESCRIPTION
Installs NuGet CLI and adds it to the path.

.PARAMETER Path
Path to download and execute nuget.exe from.

.EXAMPLE
Install-NugetCli

.NOTES
N/A
#>
function Install-NugetCli {
    [CmdletBinding()]
    param (
        [String]$Path = ( Join-Path -Path $env:APPDATA -ChildPath 'NuGet' )
    )

    $null = New-Item -Path $Path -ItemType Directory -Force -ErrorAction SilentlyContinue
    $currentProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Write-Host -Object "Downloading nuget.exe to $Path..."
    Invoke-WebRequest `
        -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' `
        -UseBasicParsing `
        -OutFile "$Path/nuget.exe"
    $ProgressPreference = $currentProgressPreference
    Write-Host -Object "Adding $Path to %PATH%..."
    $null = Set-EnvironmentVariable -Name 'PATH' -Value $Path -Scope User -Append 3>&1
    $env:PATH = $Path + [System.IO.Path]::PathSeparator + $env:PATH
    Remove-Item -Path 'Alias:nuget' -ErrorAction SilentlyContinue
    Set-Alias -Name 'nuget' -Value ( Join-Path -Path $Path -ChildPath 'nuget.exe' )
    Get-Command -Name 'nuget.exe'
}