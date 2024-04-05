Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Invoke-Timeout.ps1
    }

    It 'should not throw an error using same switches as timeout.exe' {
        { Invoke-Timeout /t 1 } | Should -Not -Throw
    }

    It 'should not throw an error using /nobreak' {
        { Invoke-Timeout /t 1 /nobreak } | Should -Not -Throw
    }
}
