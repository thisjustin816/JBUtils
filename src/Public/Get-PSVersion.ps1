<#
.SYNOPSIS
A simple function wrapper for getting the value of $PSVersionTable.PSVersion.

.DESCRIPTION
A simple function wrapper for getting the value of $PSVersionTable.PSVersion, used for unit testing.

.EXAMPLE
Get-PSVersion

.NOTES
N/A
#>
function Get-PSVersion {
    [CmdletBinding()]
    param()

    $PSVersionTable.PSVersion
}