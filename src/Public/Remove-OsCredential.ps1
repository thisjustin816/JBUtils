<#
.SYNOPSIS
Removes one named account credential from the operating-system credential store.

.PARAMETER Name
Stable credential name used when saving the entry.

.PARAMETER UserName
Exact account to remove.

.PARAMETER Namespace
Application namespace used when saving the entry.
#>
function Remove-OsCredential {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
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

    if ($PSCmdlet.ShouldProcess("$Namespace/$Name ($UserName)", 'Remove OS credential')) {
        Invoke-OsCredentialStore -Operation erase -Name $Name -UserName $UserName -Namespace $Namespace
    }
}
