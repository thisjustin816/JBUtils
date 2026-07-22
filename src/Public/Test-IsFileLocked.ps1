<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Path
Parameter description

.EXAMPLE
An example

.LINK
https://mcpmag.com/articles/2018/07/10/check-for-locked-file-using-powershell.aspx

.NOTES
General notes
#>
function Test-IsFileLocked {
    [OutputType([Bool])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias('FullName', 'PSPath', 'LiteralPath', 'Path')]
        [string[]]$FilePath
    )

    process {
        foreach ($file in $FilePath) {
            $file = Convert-Path -Path $file
            if ([System.IO.File]::Exists($file)) {
                try {
                    $filestream = [System.IO.File]::Open($file, 'Open', 'Write')
                    $filestream.Close()
                    $filestream.Dispose()
                    $false
                }
                catch [System.UnauthorizedAccessException] {
                    $true
                }
                catch {
                    $true
                }
            }
        }
    }
}
