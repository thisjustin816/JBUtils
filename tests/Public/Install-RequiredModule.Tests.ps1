# Pester declares parameters in lowercase (e.g. -name on It).
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCorrectCasing', '')]
param ()

Describe 'Install-RequiredModule' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Install-RequiredModule.ps1
    }

    BeforeEach {
        Mock Install-PSResource {}
    }

    It 'should not install when an installed version already satisfies the range' {
        Mock Get-InstalledPSResource { [PSCustomObject]@{ Name = 'Probe'; Version = [Version]'5.9.0' } }

        Install-RequiredModule -Name Probe -Version '[5.7.1,5.999.999]'

        Should -Invoke Install-PSResource -Exactly -Times 0
    }

    It 'should install when nothing satisfies the range' {
        Mock Get-InstalledPSResource {}

        Install-RequiredModule -Name Probe -Version '[5.7.1,5.999.999]'

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $Name -eq 'Probe' -and
            $Version -eq '[5.7.1,5.999.999]' -and
            $Scope -eq 'CurrentUser' -and
            $TrustRepository -eq $true
        }
    }

    It 'should ask for the same range it checked, so a stale version cannot be reinstalled' {
        Mock Get-InstalledPSResource {}

        Install-RequiredModule -Name Probe -Version '[4.1.0,]'

        Should -Invoke Get-InstalledPSResource -Exactly -Times 1 -ParameterFilter {
            $Version -eq '[4.1.0,]'
        }
        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $Version -eq '[4.1.0,]'
        }
    }

    It 'should omit Version entirely when none is requested' {
        Mock Get-InstalledPSResource {}

        Install-RequiredModule -Name Probe

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            -not $PSBoundParameters.ContainsKey('Version')
        }
    }

    It 'should honor an explicit scope and repository' {
        Mock Get-InstalledPSResource {}

        Install-RequiredModule -Name Probe -Scope AllUsers -Repository PSGallery

        Should -Invoke Install-PSResource -Exactly -Times 1 -ParameterFilter {
            $Scope -eq 'AllUsers' -and $Repository -eq 'PSGallery'
        }
    }

    It 'should install nothing under WhatIf' {
        Mock Get-InstalledPSResource {}

        Install-RequiredModule -Name Probe -WhatIf

        Should -Invoke Install-PSResource -Exactly -Times 0
    }
}
