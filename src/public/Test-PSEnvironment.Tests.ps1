Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/Get-PSVersion.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1

        Mock Get-PSVersion {
            [System.Version]::new('5.1.5555')
        }
    }

    It 'should pass when the version is in range' {
        { Test-PSEnvironment -MinimumVersion 5.0.0 -MaximumVersion 7.0.0 -CheckAdmin $false } |
            Should -Not -Throw
    }

    It 'should throw when the version is under the minimum' {
        { Test-PSEnvironment -MinimumVersion 5.2.0 -MaximumVersion 7.0.0 -CheckAdmin $false } |
            Should -Throw 'The minimum version*'
    }

    It 'should throw when the version over the maximum' {
        { Test-PSEnvironment -MinimumVersion 5.0.0 -MaximumVersion 5.1.5554 -CheckAdmin $false } |
            Should -Throw 'The maximum version*'
    }
}
