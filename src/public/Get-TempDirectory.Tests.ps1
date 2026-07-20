Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/Get-TempDirectory.ps1
    }

    It 'should return an existing directory path' {
        Test-Path -Path (Get-TempDirectory) -PathType Container | Should -BeTrue
    }

    It 'should match the runtime temp path resolver' {
        Get-TempDirectory | Should -Be ([System.IO.Path]::GetTempPath())
    }
}
