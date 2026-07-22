<#
.SYNOPSIS
Tests whether the current console is running with admin priviledges.

.DESCRIPTION
Tests whether the current console is running with admin priviledges.

.EXAMPLE
Test-IsAdmin

.NOTES
N/A
#>
function Test-IsAdmin {
    [OutputType([Bool])]
    [CmdletBinding()]
    param ()

    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
}