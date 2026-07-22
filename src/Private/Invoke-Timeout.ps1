<#
.SYNOPSIS
Wrapper for timeout.exe to support Pester mocking.

.DESCRIPTION
Wrapper for timeout.exe to support Pester mocking.

.EXAMPLE
Invoke-Timeout /t 30

.NOTES
N/A
#>

function Invoke-Timeout {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('/t')]
        [String]$TimeSwitch,
        [Parameter(Mandatory = $true)]
        [Int]$Seconds,
        [ValidateSet('/nobreak')]
        [String]$NoBreakSwitch
    )

    $timeout = Get-Command -Name "$env:windir/System32/timeout.exe" -ErrorAction Stop

    $ArgumentList = ($TimeSwitch, $Seconds)
    if ($NoBreakSwitch) {
        $ArgumentList += $NoBreakSwitch
    }

    $stderrOutFile = New-TemporaryFile
    try {
        Start-Process `
            -FilePath $timeout.Source `
            -ArgumentList $ArgumentList `
            -NoNewWindow `
            -Wait `
            -ErrorAction Stop
    }
    catch {
        Write-Verbose -Message $_.Exception.Message
        Start-Process `
            -FilePath $timeout.Source `
            -ArgumentList $ArgumentList `
            -Wait `
            -RedirectStandardError $stderrOutFile.FullName
    }

    $stdErr = Get-Content -Path $stderrOutFile.FullName -Raw
    $stderrOutFile | Remove-Item -Force -ErrorAction SilentlyContinue
    if ($null -ne $stdErr) {
        throw $stdErr
    }
}
