<#
.SYNOPSIS
Installs a module unless an installed version already satisfies the requested version.

.DESCRIPTION
Modules install side by side, so acquiring a newer version is the same operation as a first install
and there is no separate update to perform. This checks what is already available and calls
Install-PSResource only when nothing satisfies the request, which makes it safe to call on every run.

Requires Microsoft.PowerShell.PSResourceGet, which ships inside PowerShell 7 and installs from the
gallery on Windows PowerShell 5.1. There is deliberately no PowerShellGet fallback: Install-Module
cannot express a version range, which is the whole point of this function.

.PARAMETER Name
The module to install.

.PARAMETER Version
A NuGet version range or an exact version, as Install-PSResource takes it. An open upper bound such
as '[5.1.0,]' reads as "this or newer"; omit the parameter to accept any version.

.PARAMETER Scope
Where to install when an install is needed.

.PARAMETER Repository
The repository to install from. Defaults to whatever Install-PSResource resolves.

.OUTPUTS
None.

.EXAMPLE
Install-RequiredModule -Name Pester -Version '[5.7.1,5.999.999]'

.EXAMPLE
Install-RequiredModule -Name PSModuleUtils -Version '[4.1.0,]'

.NOTES
N/A
#>
function Install-RequiredModule {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Void])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [ValidateNotNullOrEmpty()]
        [String]$Version,

        [ValidateSet('CurrentUser', 'AllUsers')]
        [String]$Scope = 'CurrentUser',

        [ValidateNotNullOrEmpty()]
        [String]$Repository
    )

    $resourceParameters = @{ Name = $Name }
    if ($Version) {
        $resourceParameters.Version = $Version
    }

    $installed = Get-InstalledPSResource @resourceParameters -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if ($installed) {
        Write-Verbose -Message "$Name $($installed.Version) already satisfies '$Version'."
    }
    elseif ($PSCmdlet.ShouldProcess($Name, 'Install module')) {
        $installParameters = $resourceParameters + @{
            Scope           = $Scope
            TrustRepository = $true
            ErrorAction     = 'Stop'
        }
        if ($Repository) {
            $installParameters.Repository = $Repository
        }

        Write-Verbose -Message "Installing $Name '$Version'."
        Install-PSResource @installParameters
    }
}
