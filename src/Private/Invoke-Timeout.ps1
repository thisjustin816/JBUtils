<#
.SYNOPSIS
Internal: invokes timeout.exe and reports a nonzero exit code.

.DESCRIPTION
Requires an interactive Windows console. Start-Timeout selects a PowerShell sleep loop
when the shell is non-interactive.
#>
function Invoke-Timeout {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('/t')]
        [String]$TimeSwitch,
        [Parameter(Mandatory)]
        [Int]$Seconds,
        [ValidateSet('/nobreak')]
        [String]$NoBreakSwitch
    )

    $timeout = Get-Command -Name "$env:windir/System32/timeout.exe" -ErrorAction Stop
    $argumentList = @($TimeSwitch, [String]$Seconds)
    if ($NoBreakSwitch) {
        $argumentList += $NoBreakSwitch
    }

    Invoke-NativeCommand -FilePath $timeout.Source -ArgumentList $argumentList -FailureMessage 'Timeout failed.'
}
