<#
.SYNOPSIS
Starts a System.Diagnostics.Stopwatch instance.

.DESCRIPTION
Starts a System.Diagnostics.Stopwatch instance.

.PARAMETER InputObject
An existing Stopwatch object to start.

.EXAMPLE
$sw = Start-Stopwatch

.NOTES
N/A
#>
function Start-Stopwatch {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Starting an in-memory stopwatch does not change external system state.'
    )]
    [OutputType([System.Diagnostics.Stopwatch])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [System.Object]$InputObject
    )

    process {
        if ($InputObject) {
            $InputObject.Start()
            $InputObject
        }
        else {
            [System.Diagnostics.Stopwatch]::StartNew()
        }
    }
}
