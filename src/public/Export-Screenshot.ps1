<#
.SYNOPSIS
Exports a screenshot as a bitmap.

.DESCRIPTION
Exports a screenshot as a bitmap.

.PARAMETER OutFile
Path to save the screenshot to.

.EXAMPLE
Export-Screenshot -OutFile $env:USERPROFILE/Downloads/Screenshot.bmp

.NOTES
N/A

.LINK
https://www.pdq.com/blog/capturing-screenshots-with-powershell-and-net/
#>
function Export-Screenshot {
    [CmdletBinding()]
    param (
        [String]$OutFile = "$env:TEMP/$( New-Guid ).bmp"
    )

    begin {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $Script:width = $screen.Width
        $Script:height = $screen.Height
        $Script:left = $screen.Left
        $Script:top = $screen.Top
    }

    process {
        $bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList ($Script:width, $Script:height)
        $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphic.CopyFromScreen($Script:left, $Script:top, 0, 0, $bitmap.Size)
        $bitmap.Save($OutFile)
        Get-Item -Path $OutFile
    }
}
