Describe 'Test-VersionRange' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Private/Test-VersionRange.ps1
    }

    Context 'no range' {
        It 'should accept any version when the range is <Name>' -TestCases @(
            @{ Name = 'absent'; Range = $null }
            @{ Name = 'empty'; Range = '' }
            @{ Name = 'whitespace'; Range = '   ' }
        ) {
            Test-VersionRange -Version ([Version]'1.0.0') -Range $Range | Should -BeTrue
        }
    }

    Context 'bare version is exact, not a floor' {
        # The one place PSResourceGet departs from NuGet's table. NuGet reads '1.2.3' as >= 1.2.3.
        It 'should match the same version' {
            Test-VersionRange -Version ([Version]'1.2.3') -Range '1.2.3' | Should -BeTrue
        }

        It 'should reject a newer version' {
            Test-VersionRange -Version ([Version]'1.2.4') -Range '1.2.3' | Should -BeFalse
        }

        It 'should reject an older version' {
            Test-VersionRange -Version ([Version]'1.2.2') -Range '1.2.3' | Should -BeFalse
        }
    }

    Context 'bracketed exact' {
        It 'should match only the pinned version' {
            Test-VersionRange -Version ([Version]'1.2.3') -Range '[1.2.3]' | Should -BeTrue
            Test-VersionRange -Version ([Version]'1.2.4') -Range '[1.2.3]' | Should -BeFalse
        }
    }

    Context 'open upper bound' {
        It 'should accept the boundary when inclusive' {
            Test-VersionRange -Version ([Version]'4.1.0') -Range '[4.1.0,]' | Should -BeTrue
        }

        It 'should accept newer' {
            Test-VersionRange -Version ([Version]'9.9.9') -Range '[4.1.0,]' | Should -BeTrue
        }

        It 'should reject older' {
            Test-VersionRange -Version ([Version]'4.0.9') -Range '[4.1.0,]' | Should -BeFalse
        }

        It 'should exclude the boundary when exclusive' {
            Test-VersionRange -Version ([Version]'4.1.0') -Range '(4.1.0,)' | Should -BeFalse
            Test-VersionRange -Version ([Version]'4.1.1') -Range '(4.1.0,)' | Should -BeTrue
        }
    }

    Context 'open lower bound' {
        It 'should accept the boundary when inclusive' {
            Test-VersionRange -Version ([Version]'2.0.0') -Range '[,2.0.0]' | Should -BeTrue
        }

        It 'should exclude the boundary when exclusive' {
            Test-VersionRange -Version ([Version]'2.0.0') -Range '(,2.0.0)' | Should -BeFalse
            Test-VersionRange -Version ([Version]'1.9.9') -Range '(,2.0.0)' | Should -BeTrue
        }
    }

    Context 'closed ranges' {
        It 'should accept both boundaries when inclusive' {
            Test-VersionRange -Version ([Version]'5.7.1') -Range '[5.7.1,5.999.999]' | Should -BeTrue
            Test-VersionRange -Version ([Version]'5.999.999') -Range '[5.7.1,5.999.999]' | Should -BeTrue
        }

        It 'should accept the middle' {
            Test-VersionRange -Version ([Version]'5.9.0') -Range '[5.7.1,5.999.999]' | Should -BeTrue
        }

        It 'should reject outside either end' {
            Test-VersionRange -Version ([Version]'5.7.0') -Range '[5.7.1,5.999.999]' | Should -BeFalse
            Test-VersionRange -Version ([Version]'6.0.0') -Range '[5.7.1,5.999.999]' | Should -BeFalse
        }

        It 'should exclude both boundaries when exclusive' {
            Test-VersionRange -Version ([Version]'1.0') -Range '(1.0,2.0)' | Should -BeFalse
            Test-VersionRange -Version ([Version]'2.0') -Range '(1.0,2.0)' | Should -BeFalse
            Test-VersionRange -Version ([Version]'1.5') -Range '(1.0,2.0)' | Should -BeTrue
        }

        It 'should handle a mixed inclusive minimum and exclusive maximum' {
            Test-VersionRange -Version ([Version]'1.0') -Range '[1.0,2.0)' | Should -BeTrue
            Test-VersionRange -Version ([Version]'2.0') -Range '[1.0,2.0)' | Should -BeFalse
        }
    }

    Context 'tolerance' {
        It 'should ignore surrounding whitespace' {
            Test-VersionRange -Version ([Version]'1.2.3') -Range '  1.2.3  ' | Should -BeTrue
            Test-VersionRange -Version ([Version]'1.5') -Range '[ 1.0 , 2.0 ]' | Should -BeTrue
        }
    }

    Context 'segment normalization' {
        # NuGet treats 1, 1.0, 1.0.0 and 1.0.0.0 as one version. Raw [Version] comparison does not.
        It 'should treat <Left> and <Right> as the same version' -TestCases @(
            @{ Left = '1.0.0.0'; Right = '1.0.0' }
            @{ Left = '1.0.0'; Right = '1.0.0.0' }
            @{ Left = '1.0'; Right = '1.0.0' }
            @{ Left = '2.1'; Right = '2.1.0.0' }
        ) {
            Test-VersionRange -Version ([Version]$Left) -Range $Right | Should -BeTrue
        }

        It 'should still separate genuinely different versions' {
            Test-VersionRange -Version ([Version]'1.0.1') -Range '1.0.0' | Should -BeFalse
        }

        It 'should normalize inside a range too' {
            Test-VersionRange -Version ([Version]'1.0.0.0') -Range '[1.0.0,2.0.0]' | Should -BeTrue
        }
    }

    Context 'unreadable bounds return false rather than throwing' {
        # Get-Module -ListAvailable carries no prerelease information, so this cannot judge a
        # prerelease range. False means "install it", which is the safe answer; a throw would break
        # a check the caller expects to be cheap and total.
        It 'should not throw on a <Name> range' -TestCases @(
            @{ Name = 'bare prerelease'; Range = '1.0.0-beta' }
            @{ Name = 'bracketed prerelease'; Range = '[1.0.0-beta]' }
            @{ Name = 'prerelease lower bound'; Range = '[1.0.0-beta,]' }
            @{ Name = 'prerelease upper bound'; Range = '[1.0.0,2.0.0-rc]' }
            @{ Name = 'non-numeric'; Range = 'not-a-version' }
            @{ Name = 'wildcard'; Range = '5.*' }
        ) {
            { Test-VersionRange -Version ([Version]'1.0.0') -Range $Range } | Should -Not -Throw
            Test-VersionRange -Version ([Version]'1.0.0') -Range $Range | Should -BeFalse
        }
    }
}
