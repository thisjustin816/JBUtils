Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Reset-ConsoleColor.ps1
    }

    It 'should execute without throwing an error' {
        { Reset-ConsoleColor } | Should -Not -Throw
    }
}
