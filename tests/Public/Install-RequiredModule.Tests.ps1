# Pester declares parameters in lowercase (e.g. -name on It).
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCorrectCasing', '')]
param ()

Describe 'Install-RequiredModule' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Private/Test-VersionRange.ps1
        . $PSScriptRoot/../../src/Public/Install-RequiredModule.ps1
    }

    BeforeEach {
        Mock Install-PSResource {}
        # Empty by default so cases exercise the Get-Module fallback explicitly.
        Mock Get-InstalledPSResource {}
    }

    It 'should not install when an installed version already satisfies the range' {
        Mock Get-Module { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.9.0' } }

        Install-RequiredModule -Name Probe -Version '[5.7.1,5.999.999]'

        Should -Invoke Install-PSResource -Exactly -Times 0
    }

    It 'should install when nothing satisfies the range' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -Version '[5.7.1,5.999.999]'

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $Name -eq 'Probe' -and
            $Version -eq '[5.7.1,5.999.999]' -and
            $Scope -eq 'CurrentUser' -and
            $TrustRepository -eq $true
        }
    }

    It 'should ask for the same range it checked, so a stale version cannot be reinstalled' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -Version '[4.1.0,]'

        Should -Invoke Get-Module -Exactly -Times 1 -ParameterFilter { $ListAvailable -eq $true }
        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $Version -eq '[4.1.0,]'
        }
    }

    It 'should treat a version outside the range as not installed' {
        Mock Get-Module { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'4.0.0' } }

        Install-RequiredModule -Name Probe -Version '[4.1.0,]'

        Should -Invoke Install-PSResource -Exactly -Times 1
    }

    It 'should count a module a package manager never installed' {
        Mock Get-Module { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.0.241' } }

        Install-RequiredModule -Name Probe -Version '5.0.241'

        Should -Invoke Install-PSResource -Exactly -Times 0
    }

    It 'should omit Version entirely when none is requested' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            -not $PSBoundParameters.ContainsKey('Version')
        }
    }

    It 'should honor an explicit scope and repository' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -Scope AllUsers -Repository PSGallery

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $Scope -eq 'AllUsers' -and $Repository -eq 'PSGallery'
        }
    }

    It 'should install nothing under WhatIf' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -WhatIf

        Should -Invoke Install-PSResource -Exactly -Times 0
    }

    It 'should install over a satisfying version when Force is used' {
        Mock Get-Module { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.9.0' } }

        Install-RequiredModule -Name Probe -Version '[5.7.1,5.999.999]' -Force

        Should -Invoke Get-Module -Exactly -Times 0
        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter { $Reinstall -eq $true }
    }

    It 'should not ask for a reinstall unless Force is used' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            -not $PesterBoundParameters.ContainsKey('Reinstall')
        }
    }

    It 'should forward SkipDependencyCheck when asked' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -Version '5.0.241' -SkipDependencyCheck

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $SkipDependencyCheck -eq $true -and $Version -eq '5.0.241'
        }
    }

    It 'should omit SkipDependencyCheck by default' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            -not $PesterBoundParameters.ContainsKey('SkipDependencyCheck')
        }
    }

    It 'should still honor WhatIf with Force' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -Force -WhatIf

        Should -Invoke Install-PSResource -Exactly -Times 0
    }

    It 'should prefer the package manager and skip the PSModulePath scan on a hit' {
        Mock Get-InstalledPSResource { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.9.0' } }
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -Version '[5.7.1,5.999.999]'

        Should -Invoke Install-PSResource -Exactly -Times 0
        Should -Invoke Get-Module -Exactly -Times 0
    }

    It 'should fall back to the PSModulePath scan when the package manager knows nothing' {
        Mock Get-InstalledPSResource {}
        Mock Get-Module { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.0.241' } }

        Install-RequiredModule -Name Probe -Version '5.0.241'

        Should -Invoke Get-Module -Exactly -Times 1
        Should -Invoke Install-PSResource -Exactly -Times 0
    }

    It 'should install when neither source finds a satisfying version' {
        Mock Get-InstalledPSResource {}
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -Version '5.0.241'

        Should -Invoke Install-PSResource -Exactly -Times 1
    }

    It 'should not consult either source when Force is used' {
        Mock Get-InstalledPSResource { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.9.0' } }
        Mock Get-Module { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.9.0' } }

        Install-RequiredModule -Name Probe -Force

        Should -Invoke Get-InstalledPSResource -Exactly -Times 0
        Should -Invoke Get-Module -Exactly -Times 0
        Should -Invoke Install-PSResource -Exactly -Times 1
    }

    It 'should forward AcceptLicense when asked' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe -AcceptLicense

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $AcceptLicense -eq $true
        }
    }

    It 'should omit AcceptLicense by default' {
        Mock Get-Module {}

        Install-RequiredModule -Name Probe

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            -not $PesterBoundParameters.ContainsKey('AcceptLicense')
        }
    }
}
