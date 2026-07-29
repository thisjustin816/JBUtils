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
An exact version or a NuGet version range, as Install-PSResource takes it. Mind the one place
PSResourceGet deliberately departs from NuGet's table: a bare version is the *required* version here,
not a minimum, so '5.0.241' matches only that build where NuGet would read it as "5.0.241 or newer".
Bracket the bound to get a range - '[5.1.0,]' is "this or newer". Omit the parameter to accept any
version.

.PARAMETER Scope
Where to install when an install is needed.

.PARAMETER Repository
The repository to install from. Defaults to whatever Install-PSResource resolves.

.PARAMETER Force
Installs even when a version already satisfies the request, replacing what is there. Skips the
installed-version check entirely, so this is the switch to reach for when a local copy is suspect
rather than absent.

.PARAMETER SkipDependencyCheck
Skips resolving the module's own dependencies. Worth setting for families that pin themselves as a
matched set, such as AWS.Tools, where resolving each member's graph is slow and buys nothing.

.OUTPUTS
None.

.EXAMPLE
Install-RequiredModule -Name Pester -Version '[5.7.1,5.999.999]'

.EXAMPLE
Install-RequiredModule -Name PSModuleUtils -Version '[4.1.0,]'

.EXAMPLE
Install-RequiredModule -Name AWS.Tools.ECS -Version '5.0.241' -SkipDependencyCheck

.EXAMPLE
Install-RequiredModule -Name AWS.Tools.ECS -Version '5.0.241' -Force

.LINK
https://learn.microsoft.com/nuget/concepts/package-versioning#version-ranges

.LINK
https://learn.microsoft.com/powershell/module/microsoft.powershell.psresourceget/install-psresource

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
        [String]$Repository,

        [Switch]$Force,

        [Switch]$SkipDependencyCheck
    )

    $resourceParameters = @{ Name = $Name }
    if ($Version) {
        $resourceParameters.Version = $Version
    }

    $installed = if ($Force) {
        $null
    }
    else {
        Get-InstalledPSResource @resourceParameters -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
    }

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
        if ($Force) {
            # Install-PSResource spells "replace what is already there" as -Reinstall.
            $installParameters.Reinstall = $true
        }
        if ($SkipDependencyCheck) {
            $installParameters.SkipDependencyCheck = $true
        }

        Write-Verbose -Message "Installing $Name '$Version'."
        Install-PSResource @installParameters
    }
}
