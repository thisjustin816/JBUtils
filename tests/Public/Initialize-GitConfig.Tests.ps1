Describe 'Integration Tests' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Write-ConsoleMessage.ps1
        . $PSScriptRoot/../../src/Public/Write-ProgressToHost.ps1
        . $PSScriptRoot/../../src/Public/Start-CliProcess.ps1
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        . $PSScriptRoot/../../src/Public/Initialize-GitConfig.ps1
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

Describe 'Git configuration targets' {
    BeforeAll {
        . "$PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1"
        . "$PSScriptRoot/../../src/Public/Initialize-GitConfig.ps1"
    }

    BeforeEach {
        $fixtureRoot = Join-Path $TestDrive (New-Guid).ToString()
        $caller = New-Item -ItemType Directory -Path "$fixtureRoot/caller" -Force
        $first = New-Item -ItemType Directory -Path "$fixtureRoot/first repo" -Force
        $second = New-Item -ItemType Directory -Path "$fixtureRoot/second repo" -Force
        foreach ($repository in @($caller, $first, $second)) {
            Invoke-NativeCommand -FilePath git -ArgumentList @('init', '--quiet', $repository.FullName)
        }
        Invoke-NativeCommand -FilePath git -WorkingDirectory $caller.FullName `
            -ArgumentList @('config', '--local', 'http.version', 'HTTP/2')
        Push-Location -LiteralPath $caller.FullName
    }

    AfterEach {
        Pop-Location
    }

    It 'sets every value in each requested repository and leaves the caller unchanged' {
        $first, $second | Initialize-GitConfig -UserName 'Fixture User' -UserEmail 'fixture@example.test'
        (git config --local http.version) | Should -Be 'HTTP/2'
        foreach ($repository in @($first, $second)) {
            (git -C $repository.FullName config --local http.version) | Should -Be 'HTTP/1.1'
            (git -C $repository.FullName config --local user.name) | Should -Be 'Fixture User'
            (git -C $repository.FullName config --local user.email) | Should -Be 'fixture@example.test'
        }
        $PWD.Path | Should -Be $caller.FullName
    }

    It 'throws when Git rejects the target directory' {
        $notRepository = New-Item -ItemType Directory -Path "$fixtureRoot/not a repo" -Force
        {
            Initialize-GitConfig -Path $notRepository.FullName -UserName 'Fixture User' `
                -UserEmail 'fixture@example.test'
        } | Should -Throw
        $PWD.Path | Should -Be $caller.FullName
    }
}
