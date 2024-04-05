<#
.SYNOPSIS
Checks whether the current PowerShell environment is sufficient to run the script.

.DESCRIPTION
Checks whether the current PowerShell environment is sufficient to run the script by checking the installed
version and whether it is being ran as an admin. Throws an error if those requirements are not satisfied.

.PARAMETER MinimumVersion
Minimum version of PowerShell to check for.

.PARAMETER MaximumVersion
Minimum version of PowerShell to check for.

.PARAMETER CheckAdmin
Check to see whether the prompt is running as an administrator. Defaults to true.

.EXAMPLE
Test-PSEnvironment

.EXAMPLE
Test-PSEnvironment -CheckAdmin $false -MinimumVersion '3.0'

.NOTES
General notes
#>

function Test-PSEnvironment {
    [CmdletBinding()]
    param (
        [System.Object]$MinimumVersion = [System.Version]::new('5.1.0'),
        [System.Object]$MaximumVersion = [System.Version]::new('254.254.254'),
        [bool]$CheckAdmin = $true
    )

    $ErrorActionPreference = 'Stop'

    if ($CheckAdmin -eq $true) {
        if (
            !(
                [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole(
                [Security.Principal.WindowsBuiltInRole] 'Administrator'
            )
        ) {
            Write-Error -Message 'Run command in an administrator PowerShell prompt. Process will exit.'
            Invoke-Command -ScriptBlock { timeout /t 15 }
            Stop-Process -Id $PID -PassThru | Wait-Process
        }
        else {
            Write-Verbose -Message 'Host is running as an administrator.'
        }
    }

    if ($MinimumVersion.GetType().Name -eq 'String') {
        $MinimumVersion = [System.Version]::new($MinimumVersion)
    }
    if ($MaximumVersion.GetType().Name -eq 'String') {
        $MaximumVersion = [System.Version]::new($MaximumVersion)
    }
    Write-Verbose -Message (
        "Checking host version: $( Get-PSVersion ) against minimum " +
        "version $MinimumVersion and maximum version $MaximumVersion."
    )
    if (
        $null -ne $MinimumVersion -and `
        (( Get-PSVersion ) -lt $MinimumVersion)
    ) {
        throw (
            "The minimum version of Windows PowerShell that is required by the script ($MinimumVersion) " +
            "does not match the currently running version ($( Get-PSVersion )) of Windows PowerShell."
        )
    }
    if (
        $null -ne $MaximumVersion -and `
        (( Get-PSVersion ) -gt $MaximumVersion)
    ) {
        throw (
            "The maximum version of Windows PowerShell that is required by the script ($MaximumVersion) " +
            "does not match the currently running version ($( Get-PSVersion )) of Windows PowerShell."
        )
    }
}
