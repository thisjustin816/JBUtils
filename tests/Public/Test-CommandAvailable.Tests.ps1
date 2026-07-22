Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Test-CommandAvailable.ps1
    }

    It 'should not throw when the command is available' {
        { Test-CommandAvailable -CommandName 'Get-Command' } |
            Should -Not -Throw
    }

    It 'should throw a descriptive error when the command is not available' {
        { Test-CommandAvailable -CommandName 'NoSuchCommand12345' } |
            Should -Throw '*NoSuchCommand12345*not on PATH*'
    }

    It 'should throw the custom error message when provided' {
        { Test-CommandAvailable -CommandName 'NoSuchCommand12345' -ErrorMessage 'custom message' } |
            Should -Throw 'custom message'
    }
}
