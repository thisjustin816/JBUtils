Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/Test-IsAdmin.ps1
        . $PSScriptRoot/Get-PSVersion.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1

        Mock Get-PSVersion {
            [System.Version]::new('5.1.5555')
        }
    }

    It 'should pass when the version is in range' {
        Test-PSEnvironment -MinimumVersion 5.0.0 -MaximumVersion 7.0.0 |
            Should -Be $true
    }

    It 'should not throw when the version is in range and -Exit is used' {
        { Test-PSEnvironment -MinimumVersion 5.0.0 -MaximumVersion 7.0.0 -Exit } |
            Should -Not -Throw
    }

    It 'should fail when the version is under the minimum' {
        Test-PSEnvironment -MinimumVersion 5.2.0 -MaximumVersion 7.0.0 |
            Should -Be $false

        { Test-PSEnvironment -MinimumVersion 5.2.0 -MaximumVersion 7.0.0 } |
            Should -Not -Throw
    }

    It 'should fail when the version over the maximum' {
        Test-PSEnvironment -MinimumVersion 5.0.0 -MaximumVersion 5.1.5554 |
            Should -Be $false

        { Test-PSEnvironment -MinimumVersion 5.0.0 -MaximumVersion 5.1.5554 } |
            Should -Not -Throw
    }

    It 'should throw when the version is out of range and -Exit is used' {
        { Test-PSEnvironment -MinimumVersion 5.0.0 -MaximumVersion 5.1.5554 -Exit } |
            Should -Throw
    }

    Context 'When the current host has admin rights' {
        BeforeAll {
            Mock Test-IsAdmin {
                $true
            }
        }

        It 'should pass when -CheckAdmin is used' {
            Test-PSEnvironment -CheckAdmin | Should -Be $true
        }

        It 'should not throw when -CheckAdmin and -Exit are used' {
            { Test-PSEnvironment -CheckAdmin -Exit } | Should -Not -Throw
        }
    }

    Context 'When the current host does not have admin rights' {
        BeforeAll {
            Mock Test-IsAdmin {
                $false
            }
        }

        It 'should fail when -CheckAdmin is used' {
            Test-PSEnvironment -CheckAdmin | Should -Be $false
        }

        It 'should throw when -CheckAdmin and -Exit are used' {
            { Test-PSEnvironment -CheckAdmin -Exit } | Should -Throw
        }
    }
}
