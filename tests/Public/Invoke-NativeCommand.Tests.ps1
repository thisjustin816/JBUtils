Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        $Script:PwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    }

    It 'should stream native output and not throw when the command succeeds' {
        $parameters = @{
            FilePath       = $PwshPath
            ArgumentList   = @('-NoProfile', '-Command', "'native output'; exit 0")
            FailureMessage = 'Command failed.'
        }

        Invoke-NativeCommand @parameters | Should -Be 'native output'
    }

    It 'should throw the supplied message and exit code when the command fails' {
        $parameters = @{
            FilePath       = $PwshPath
            ArgumentList   = @('-NoProfile', '-Command', 'exit 7')
            FailureMessage = 'Command failed.'
        }

        { Invoke-NativeCommand @parameters } |
            Should -Throw 'Command failed. Exit code: 7'
    }

    It 'should default the failure message to one naming the command' {
        $parameters = @{
            FilePath     = $PwshPath
            ArgumentList = @('-NoProfile', '-Command', 'exit 5')
        }

        { Invoke-NativeCommand @parameters } |
            Should -Throw "'$PwshPath' failed. Exit code: 5"
    }

    It 'should run in the requested directory and restore the caller location' {
        $workingDirectory = Join-Path $TestDrive 'working'
        $null = New-Item -ItemType Directory -Path $workingDirectory
        $testScript = Join-Path $TestDrive 'verify-location.ps1'
        Set-Content -Path $testScript -Value (
            'if ((Get-Location).Path -ne $args[0]) { exit 9 }'
        )
        $callerLocation = (Get-Location).Path
        $parameters = @{
            FilePath         = $PwshPath
            ArgumentList     = @('-NoProfile', '-File', $testScript, $workingDirectory)
            FailureMessage   = 'Wrong working directory.'
            WorkingDirectory = $workingDirectory
        }

        Invoke-NativeCommand @parameters

        (Get-Location).Path | Should -Be $callerLocation
    }

    It 'should restore the caller location when the command fails' {
        $workingDirectory = Join-Path $TestDrive 'failing'
        $null = New-Item -ItemType Directory -Path $workingDirectory
        $callerLocation = (Get-Location).Path
        $parameters = @{
            FilePath         = $PwshPath
            ArgumentList     = @('-NoProfile', '-Command', 'exit 3')
            FailureMessage   = 'Command failed.'
            WorkingDirectory = $workingDirectory
        }

        { Invoke-NativeCommand @parameters } | Should -Throw

        (Get-Location).Path | Should -Be $callerLocation
    }
}

Describe 'Isolated native command environments' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        $script:PwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    }

    BeforeEach {
        $script:PriorValue = $env:JBUTILS_NATIVE_TEST
        $env:JBUTILS_NATIVE_TEST = 'parent-value'
    }

    AfterEach {
        $env:JBUTILS_NATIVE_TEST = $script:PriorValue
    }

    It 'passes an override only to the child process' {
        $output = Invoke-NativeCommand -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-Command', '$env:JBUTILS_NATIVE_TEST'
        ) -Environment @{ JBUTILS_NATIVE_TEST = 'child-value' }

        $output | Should -Be 'child-value'
        $env:JBUTILS_NATIVE_TEST | Should -Be 'parent-value'
    }

    It 'removes a child variable without changing the parent' {
        $output = Invoke-NativeCommand -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-Command', 'Test-Path Env:JBUTILS_NATIVE_TEST'
        ) -Environment @{ JBUTILS_NATIVE_TEST = $null }

        $output | Should -Be 'False'
        $env:JBUTILS_NATIVE_TEST | Should -Be 'parent-value'
    }

    It 'preserves an explicitly empty child variable' -Skip:($PSVersionTable.PSVersion -lt [Version]'7.5') {
        $output = Invoke-NativeCommand -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-Command', 'Test-Path Env:JBUTILS_NATIVE_TEST; $env:JBUTILS_NATIVE_TEST.Length'
        ) -Environment @{ JBUTILS_NATIVE_TEST = '' }

        $output | Should -Be @('True', '0')
        $env:JBUTILS_NATIVE_TEST | Should -Be 'parent-value'
    }

    It 'preserves argument data and the requested working directory' {
        $directory = Join-Path $TestDrive 'child directory'
        $null = New-Item -ItemType Directory -Path $directory
        $file = Join-Path $TestDrive 'arguments.ps1'
        Set-Content -LiteralPath $file -Value '$args[0]; (Get-Location).Path; $env:JBUTILS_NATIVE_TEST'
        $literal = 'spaces "quotes" $(throw 1) & | %PATH%'

        $output = @(Invoke-NativeCommand -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-File', $file, $literal
        ) -WorkingDirectory $directory -Environment @{ JBUTILS_NATIVE_TEST = 'isolated-value' })

        $output | Should -Be @($literal, $directory, 'isolated-value')
        $env:JBUTILS_NATIVE_TEST | Should -Be 'parent-value'
    }

    It 'keeps the supplied failure message and exit code' {
        {
            Invoke-NativeCommand -FilePath $script:PwshPath -ArgumentList @(
                '-NoProfile', '-Command', 'exit 7'
            ) -Environment @{ JBUTILS_NATIVE_TEST = 'child-value' } -FailureMessage 'Child failed.'
        } | Should -Throw '*Child failed. Exit code: 7*'
        $env:JBUTILS_NATIVE_TEST | Should -Be 'parent-value'
    }

    It 'captures both native streams without a pipe deadlock' {
        $command = '1..1000 | ForEach-Object { [Console]::Out.WriteLine("out"); [Console]::Error.WriteLine("err") }'
        $output = @(Invoke-NativeCommand -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-Command', $command
        ) -Environment @{ JBUTILS_NATIVE_TEST = 'child-value' } 2>&1)

        @($output | Where-Object { "$_" -eq 'out' }).Count | Should -Be 1000
        @($output | Where-Object { "$_" -eq 'err' }).Count | Should -Be 1000
    }

    It 'keeps concurrent invocations and the parent environment separate' {
        $source = (Resolve-Path -LiteralPath "$PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1").ProviderPath
        $command = {
            param($Source, $Executable, $Value)
            . $Source
            Invoke-NativeCommand -FilePath $Executable -ArgumentList @(
                '-NoProfile', '-Command', 'Start-Sleep -Milliseconds 100; $env:JBUTILS_NATIVE_TEST'
            ) -Environment @{ JBUTILS_NATIVE_TEST = $Value }
        }
        $first = [PowerShell]::Create()
        $second = [PowerShell]::Create()
        try {
            $null = $first.AddScript($command).AddArgument($source).AddArgument($script:PwshPath).AddArgument('first')
            $null = $second.AddScript($command).AddArgument($source).AddArgument($script:PwshPath).AddArgument('second')
            $firstResult = $first.BeginInvoke()
            $secondResult = $second.BeginInvoke()

            @($first.EndInvoke($firstResult)) | Should -Be @('first')
            @($second.EndInvoke($secondResult)) | Should -Be @('second')
            $first.Streams.Error.Count | Should -Be 0
            $second.Streams.Error.Count | Should -Be 0
            $env:JBUTILS_NATIVE_TEST | Should -Be 'parent-value'
        }
        finally {
            $first.Dispose()
            $second.Dispose()
        }
    }
}

Describe 'Child environment invocation boundaries' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        $script:PwshPath = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    }

    It 'uses the first application when PATH has multiple matches' {
        Mock Get-Command {
            [PSCustomObject]@{ Source = $script:PwshPath }
            [PSCustomObject]@{ Source = 'not-an-executable' }
        } -ParameterFilter { $Name -eq 'fixture-native' }

        Invoke-NativeCommand -FilePath 'fixture-native' -ArgumentList @(
            '-NoProfile', '-Command', "'selected-first'"
        ) -Environment @{} | Should -Be 'selected-first'
    }

    It 'rejects invalid overrides without exposing their value' {
        $sensitiveValue = 'synthetic-invalid-value'
        $failure = try {
            Invoke-NativeCommand -FilePath $script:PwshPath -Environment @{ 'invalid=name' = $sensitiveValue }
        }
        catch { $_ }

        $failure.Exception.Message | Should -Match 'valid variable names'
        $failure.Exception.Message | Should -Not -Match $sensitiveValue
    }

    It 'supports Windows command wrappers with child-only variables' -Skip:(-not $IsWindows) {
        $wrapper = Join-Path $TestDrive 'native wrapper.cmd'
        Set-Content -LiteralPath $wrapper -Value @('@echo off', 'echo %JBUTILS_WRAPPER_TEST%', 'exit /b 0')
        $output = Invoke-NativeCommand -FilePath $wrapper -Environment @{ JBUTILS_WRAPPER_TEST = 'child-wrapper' }

        $output | Should -Be 'child-wrapper'
        $env:JBUTILS_WRAPPER_TEST | Should -BeNullOrEmpty
    }
}

Describe 'Literal native arguments' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        $Script:PwshPath = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
    }

    It 'preserves wildcard argument data with child isolation <Isolated>' -ForEach @(
        @{ Isolated = $false }
        @{ Isolated = $true }
    ) {
        $directory = Join-Path $TestDrive "literal-$Isolated"
        $null = New-Item -ItemType Directory -Path $directory
        Set-Content -LiteralPath (Join-Path $directory 'matching.txt') -Value 'fixture'
        $probe = Join-Path $TestDrive "arguments-$Isolated.ps1"
        Set-Content -LiteralPath $probe -Value '$args | ConvertTo-Json -Compress'
        $expected = @('*', '*.txt', 'spaces "quotes" $(throw 1)', '')
        $parameters = @{
            FilePath         = $Script:PwshPath
            ArgumentList     = @('-NoProfile', '-File', $probe) + $expected
            WorkingDirectory = $directory
        }
        if ($Isolated) { $parameters.Environment = @{} }

        $actual = Invoke-NativeCommand @parameters | ConvertFrom-Json

        $actual | Should -Be $expected
    }
}
