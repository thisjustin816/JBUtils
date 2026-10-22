Describe 'Timeout exit handling' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        . $PSScriptRoot/../../src/Private/Invoke-Timeout.ps1
    }

    BeforeEach {
        $script:nativeExitCode = 0
        Mock Get-Command { [PSCustomObject]@{ Source = 'fixture-timeout.exe' } }
        Mock Start-Process {
            $process = [PSCustomObject]@{ ExitCode = $script:nativeExitCode }
            $process | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
            $process
        }
        Mock Invoke-NativeCommand {
            if ($script:nativeExitCode -ne 0) { throw "Timeout failed. Exit code: $script:nativeExitCode" }
        }
    }

    It 'accepts a successful timeout' {
        { Invoke-Timeout /t 1 } | Should -Not -Throw
    }

    It 'reports a failed timeout' {
        $script:nativeExitCode = 23
        { Invoke-Timeout /t 1 } | Should -Throw '*Exit code: 23*'
    }

    It 'passes the no-break switch to the native command' {
        Invoke-Timeout /t 2 /nobreak
        Should -Invoke Invoke-NativeCommand -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'fixture-timeout.exe' -and ($ArgumentList -join ' ') -eq '/t 2 /nobreak'
        }
    }
}

Describe 'Integration Tests' -Tag 'Integration', 'HostIntegration' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        . $PSScriptRoot/../../src/Private/Invoke-Timeout.ps1
    }

    It 'should not throw an error using same switches as timeout.exe' {
        { Invoke-Timeout /t 1 } | Should -Not -Throw
    }

    It 'should not throw an error using /nobreak' {
        { Invoke-Timeout /t 1 /nobreak } | Should -Not -Throw
    }
}
