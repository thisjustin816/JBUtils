<#
.SYNOPSIS
Reads a named credential from the current user's operating-system credential store.

.DESCRIPTION
Uses Git Credential Manager with Windows Credential Manager, macOS Keychain or Linux Secret Service.
Requires Git Credential Manager and an available, unlocked user store. Never starts authentication
or falls back to plaintext storage. A missing or inaccessible credential raises an error.

.PARAMETER Name
Stable credential name containing letters, digits, periods, underscores or hyphens.

.PARAMETER UserName
Account associated with the credential.

.PARAMETER Namespace
Application namespace isolating these entries from Git credentials and other applications.

.OUTPUTS
System.Management.Automation.PSCredential
#>
function Get-OsCredential {
    [CmdletBinding()]
    [OutputType([PSCredential])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[A-Za-z0-9_.-]{1,128}\z')]
        [String]$Name,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$UserName,
        [ValidatePattern('\A[A-Za-z0-9_.-]{1,64}\z')]
        [String]$Namespace = 'JBUtils'
    )

    Invoke-OsCredentialStore -Operation get -Name $Name -UserName $UserName -Namespace $Namespace
}
