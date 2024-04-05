<#
.SYNOPSIS
Create a function to retrieve the SID for a user account on a machine.
#>
function Get-UsernameSID($AccountName) {
    $ntUserObject = New-Object System.Security.Principal.NTAccount($AccountName)
    $ntUserSid = $ntUserObject.Translate([System.Security.Principal.SecurityIdentifier])
    $ntUserSid.Value
}