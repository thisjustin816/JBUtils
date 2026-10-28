<#
.SYNOPSIS
Saves a named credential in the current user's operating-system credential store.

.DESCRIPTION
Uses Git Credential Manager with the native OS store. Sends the password through redirected stdin,
never command arguments. Does not modify Git settings or persist a plaintext fallback. The store
must be available and unlocked. Passwords must be nonempty single-line values.

.PARAMETER Name
Stable credential name containing letters, digits, periods, underscores or hyphens.

.PARAMETER Credential
Account and password to save.

.PARAMETER Namespace
Application namespace isolating these entries from Git credentials and other applications.
#>
function Set-OsCredential {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[A-Za-z0-9_.-]{1,128}\z')]
        [String]$Name,
        [Parameter(Mandatory)]
        [PSCredential]$Credential,
        [ValidatePattern('\A[A-Za-z0-9_.-]{1,64}\z')]
        [String]$Namespace = 'JBUtils'
    )

    if ($PSCmdlet.ShouldProcess("$Namespace/$Name", 'Save OS credential')) {
        Invoke-OsCredentialStore -Operation store -Name $Name -Credential $Credential -Namespace $Namespace
    }
}
