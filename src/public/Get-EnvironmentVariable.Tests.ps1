Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/Get-EnvironmentVariable.ps1
        $Script:existingPath = $env:PATH
        $Script:existingTemp = $env:TEMP
        $env:PATH = 'this/is/a/path'
        $env:TEMP = 'temp/path'
    }

    It 'should get an environment variable in the current process scope' {
        ( Get-EnvironmentVariable -Name PATH ).Value | Should -Be $env:PATH
    }

    It 'should return a custom environment variable object' {
        $var = Get-EnvironmentVariable -Name PATH
        $var.Name | Should -Not -BeNullOrEmpty
        $var.Value | Should -Not -BeNullOrEmpty
        $var.Scope | Should -Not -BeNullOrEmpty
    }

    It 'should be able to return an array of results' {
        $vars = Get-EnvironmentVariable -Name ('PATH', 'TEMP')
        $vars.Count | Should -Be 2
    }

    AfterAll {
        $env:PATH = $Script:existingPath
        $env:TEMP = $Script:existingTemp
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Get-EnvironmentVariable.ps1
    }

    It 'should get an environment variable in the current process scope' {
        ( Get-EnvironmentVariable -Name PATH ).Value | Should -Be $env:PATH
    }

    It 'should return a custom environment variable object' {
        $var = Get-EnvironmentVariable -Name PATH
        $var.Name | Should -Not -BeNullOrEmpty
        $var.Value | Should -Not -BeNullOrEmpty
        $var.Scope | Should -Not -BeNullOrEmpty
    }

    It 'should be able to return an array of results' {
        $vars = Get-EnvironmentVariable -Name ('PATH', 'TEMP')
        $vars.Count | Should -Be 2
    }
}
