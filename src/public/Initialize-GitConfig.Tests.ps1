Describe 'Integration Tests' {
    BeforeAll {
        . $PSScriptRoot/Write-ProgressToHost.ps1
        . $PSScriptRoot/Start-CliProcess.ps1
        . $PSScriptRoot/Initialize-GitConfig.ps1
    }

    It 'should set local config for all paths' {
        $Git = Get-Command -Name git.exe | Select-Object -ExpandProperty Source
        $path1 = New-Item -Path "$TestDrive/$( New-Guid )" -ItemType Directory
        $path2 = New-Item -Path "$TestDrive/$( New-Guid )" -ItemType Directory
        foreach ($path in $path1.FullName, $path2.FullName) {
            Start-CliProcess -FilePath $Git -ArgumentList init -WorkingDirectory $path
        }
        { $path1, $path2 | Initialize-GitConfig } | Should -Not -Throw
    }

    It 'should only have 1 entry for user name and email in config' {
        $Git = Get-Command -Name git.exe | Select-Object -ExpandProperty Source
        $path = New-Item -Path "$TestDrive/$( New-Guid )" -ItemType Directory
        $path | Get-Item
        Start-CliProcess -FilePath $Git -ArgumentList init -WorkingDirectory $path.FullName
        Push-Location -Path $path.FullName
        Initialize-GitConfig
        ( git config --local -l ) | Where-Object -FilterScript { $_ -match 'user\.name' } |
            Should -HaveCount 1
        ( git config --local -l ) | Where-Object -FilterScript { $_ -match 'user\.email' } |
            Should -HaveCount 1
        Pop-Location
    }
}
