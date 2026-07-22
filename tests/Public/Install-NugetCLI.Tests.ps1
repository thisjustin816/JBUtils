Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Set-EnvironmentVariable.ps1
        . $PSScriptRoot/../../src/Public/Add-AzPipelinesPathEntry.ps1
        . $PSScriptRoot/../../src/Public/Get-EnvironmentVariable.ps1
        . $PSScriptRoot/../../src/Public/Install-NugetCLI.ps1
    }

    It 'should download and add nuget to the path' {
        Install-NugetCli
        $cmd = Get-Command -Name 'nuget'
        $cmd.Source | Should -Be (Join-Path -Path $env:APPDATA -ChildPath 'NuGet/nuget.exe')
        $path = Get-EnvironmentVariable -Name PATH -Scope User
        $path.Value | Should -Match ([Regex]::Escape($env:APPDATA + [System.IO.Path]::DirectorySeparatorChar + 'NuGet'))
    }

    It 'should not remove other items from PATH' {
        Get-Command -Name git | Should -Not -BeNullOrEmpty
        Get-Command -Name cmd | Should -Not -BeNullOrEmpty
        Get-Command -Name powershell | Should -Not -BeNullOrEmpty
    }
}
