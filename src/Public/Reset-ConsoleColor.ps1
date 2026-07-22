<#
.SYNOPSIS
Resets the current console to the default colors.

.DESCRIPTION
Resets the current console to the default colors.

.EXAMPLE
Reset-ConsoleColor

.NOTES
N/A
#>

function Reset-ConsoleColor {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Resetting colors affects only the current console presentation.'
    )]
    [CmdletBinding()]
    param ()
    [Console]::ResetColor()
}
