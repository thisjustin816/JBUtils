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
    [CmdletBinding()]
    param ()
    [Console]::ResetColor()
}