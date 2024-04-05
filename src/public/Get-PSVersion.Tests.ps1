Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Get-PSVersion.ps1
    }

    It 'should return the correct value' {
        Get-PSVersion | Should -BeExactly $PSVersionTable.PSVersion
    }
}
