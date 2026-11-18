<#
.SYNOPSIS
Internal: Exchanges the private credential protocol with a redirected subprocess.
#>
function Invoke-OsCredentialProtocol {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [Diagnostics.ProcessStartInfo]$StartInfo,
        [Parameter(Mandatory)]
        [String]$InputText
    )

    try {
        Invoke-ProcessExchange -StartInfo $StartInfo -InputText $InputText
    }
    catch {
        throw 'OS credential store operation failed. Check that its session is available and unlocked.'
    }
    finally { $InputText = $null }
}
