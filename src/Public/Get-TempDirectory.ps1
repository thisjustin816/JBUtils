<#
.SYNOPSIS
Gets a temporary directory path for the current host.

.DESCRIPTION
Uses the runtime temp-path resolver because $env:TEMP is not set reliably on macOS or Linux.

.OUTPUTS
System.String

.EXAMPLE
Get-TempDirectory

.NOTES
N/A
#>
function Get-TempDirectory {
    [CmdletBinding()]
    [OutputType([String])]
    param()

    [System.IO.Path]::GetTempPath()
}
