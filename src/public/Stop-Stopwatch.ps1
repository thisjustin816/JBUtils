<#
.SYNOPSIS
Stops a stopwatch started from Start-Stopwatch.

.DESCRIPTION
Stops a stopwatch started from Start-Stopwatch.

.PARAMETER InputObject
A stopwatch object from Start-StopWatch.

.EXAMPLE
$sw = Start-Stopwatch; $sw | Stop-Stopwatch

.NOTES
N/A
#>
function Stop-Stopwatch {
    [OutputType([System.Diagnostics.Stopwatch])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Object]$InputObject
    )

    process {
        $InputObject.Stop()
        $InputObject
    }
}