<#
.SYNOPSIS
Checks whether the current PowerShell environment is sufficient to run the script.

.DESCRIPTION
Checks whether the current PowerShell environment is sufficient to run the script by checking the installed
version and whether it is being ran as an admin.

.PARAMETER MinimumVersion
Minimum version of PowerShell to check for.

.PARAMETER MaximumVersion
Minimum version of PowerShell to check for.

.PARAMETER CheckAdmin
Check to see whether the prompt is running as an administrator.

.PARAMETER Exit
Throws an error instead of returning $false.

.EXAMPLE
Test-PSEnvironment

.EXAMPLE
Test-PSEnvironment -CheckAdmin -Exit

.NOTES
N/A
#>

function Test-PSEnvironment {
    [CmdletBinding()]
    param (
        [AllowEmptyString()]
        [AllowNull()]
        [System.Object]
        $MinimumVersion = [System.Version]::new('5.1.0'),

        [AllowEmptyString()]
        [AllowNull()]
        [System.Object]
        $MaximumVersion,

        [Switch]
        $CheckAdmin,

        [Switch]
        $Exit
    )

    $errMsg = @()
    if ($CheckAdmin -eq $true) {
        if ( Test-IsAdmin ) {
            Write-Verbose -Message 'Host is running with admin priviledges.'
        }
        else {
            $errMsg += 'Host is not running with admin priviledges.'
        }
    }

    $hostVersion = Get-PSVersion
    if ($MinimumVersion) {
        if ($MinimumVersion.GetType().Name -eq 'String') {
            $MinimumVersion = [System.Version]::new($MinimumVersion)
        }
        Write-Verbose -Message (
            "Checking host version: $hostVersion against minimum " +
            "version $MinimumVersion."
        )
        if ($hostVersion -lt $MinimumVersion) {
            $errMsg +=  (
                "The minimum version of Windows PowerShell that is required by the script ($MinimumVersion) " +
                "does not match the currently running version ($hostVersion) of Windows PowerShell."
            )
        }
    }

    if ($MaximumVersion) {
        if ($MaximumVersion.GetType().Name -eq 'String') {
            $MaximumVersion = [System.Version]::new($MaximumVersion)
        }
        Write-Verbose -Message (
            "Checking host version: $hostVersion against maximum " +
            "version $MaximumVersion."
        )
        if ($hostVersion -gt $MaximumVersion) {
            $errMsg +=  (
                "The maximum version of Windows PowerShell that is required by the script ($MaximumVersion) " +
                "does not match the currently running version ($hostVersion) of Windows PowerShell."
            )
        }
    }

    if ($errMsg) {
        $false
        if ($Exit) {
            throw $errMsg
        }
        else {
            Write-Host -Object $errMsg
        }
    }
    else {
        $true
    }
}
