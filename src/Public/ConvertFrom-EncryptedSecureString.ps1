<#
.SYNOPSIS
Converts a SecureString to plain text in one step.

.DESCRIPTION
Converts a SecureString to plain text in one step.

.PARAMETER SecureString
SecureString to convert.

.EXAMPLE
$secureStringVar | ConvertFrom-EncryptedSecureString

.LINK
https://stackoverflow.com/a/28353003/14628263

.NOTES
N/A
#>
function ConvertFrom-EncryptedSecureString {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [SecureString]$SecureString
    )

    process {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
}
