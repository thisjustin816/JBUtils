<#
.SYNOPSIS
Waits for a specified time with the option to press a key to continue.

.DESCRIPTION
Waits for a specified time with the option to press a key to continue.

.PARAMETER Seconds
The amount of seconds to wait before continuing.

.PARAMETER NoBreak
Removes the option to press a key to continue.

.EXAMPLE
Start-Timeout -Seconds 5

.NOTES
Is just a more PS friendly wrapper for timeout.exe
#>

function Start-Timeout {
    [CmdletBinding()]
    param (
        [Int]$Seconds = 0,
        [Switch]$NoBreak
    )

    if (Test-IsNonInteractiveShell) {
        for ($i = $Seconds; $i -ge 0; $i--) {
            $activity = "Waiting for $i seconds,"
            Write-Progress -Activity $activity -Status 'press CTRL+C to quit ...'
            Start-Sleep -Seconds 1
        }
        Write-Progress $activity -Completed
    }
    else {
        . "$PSScriptRoot/../private/Invoke-Timeout.ps1"
        $scriptString = "Invoke-Timeout /t $Seconds"
        if ($NoBreak) {
            $scriptString += ' /nobreak'
        }
        $timeout = [ScriptBlock]::Create($scriptString)
        Invoke-Command -ScriptBlock $timeout
    }
}
