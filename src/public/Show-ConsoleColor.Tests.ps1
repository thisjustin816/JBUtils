Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Show-ConsoleColor.ps1
    }

    It 'should show available console colors' {
        Show-ConsoleColor 6>&1 | Should -Not -BeNullOrEmpty
    }
}
