<#
.SYNOPSIS
Creates a PSCredential object for a Personal Access Token.

.DESCRIPTION
Creates a PSCredential object for a Personal Access Token.

.PARAMETER Pat
The Personal Access Token (PAT) to use.

.PARAMETER Username
The username to associate with the PAT.

.EXAMPLE
An example

.NOTES
General notes
Parameter description

.PARAMETER Username
Parameter description

.EXAMPLE
Get-PatPSCredential -Pat 'my-personal-access-token' -Username 'my-username'

.NOTES
N/A
#>
function Get-PatPSCredential {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN,

        [String]$Username = 'PAT'
    )

    if ([string]::IsNullOrEmpty($Pat)) {
        throw "No PAT provided and SYSTEM_ACCESSTOKEN environment variable is not set"
    }

    $securePat = ConvertTo-SecureString -String $Pat -AsPlainText -Force
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $securePat
}
