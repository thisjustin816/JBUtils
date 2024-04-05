Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Write-ProgressToHost.ps1
        . $PSScriptRoot/Start-CliProcess.ps1
    }

    It 'should not throw if the exit code is 0' {
        { Start-CliProcess -FilePath "$env:SYSTEMROOT/System32/cmd.exe" -ArgumentList '/c "exit /b 0"' } |
            Should -Not -Throw
    }

    It 'should throw the same exit code as the process' {
        { Start-CliProcess -FilePath "$env:SYSTEMROOT/System32/cmd.exe" -ArgumentList '/c "exit /b 2"' } |
            Should -Throw
        try {
            Start-CliProcess -FilePath "$env:SYSTEMROOT/System32/cmd.exe" -ArgumentList '/c "exit /b 2"'
        }
        catch {
            $_.TargetObject | Should -BeExactly 2
        }
    }

    It 'should ignore console output if PassThru is not used' {
        Start-CliProcess -FilePath "$env:SYSTEMROOT/System32/cmd.exe" -ArgumentList '/c "echo hello"' |
            Should -BeNullOrEmpty
    }

    It 'should capture console output if PassThru is used' {
        Start-CliProcess -FilePath "$env:SYSTEMROOT/System32/cmd.exe" -ArgumentList '/c "echo hello"' -PassThru |
            Should -Be 'hello'
    }

    It 'should output the full command without verbose if ran on an agent' {
        $ProgressPreference = 'Continue'
        if (!$env:AGENT_JOBNAME) {
            $env:AGENT_JOBNAME = 'PesterTest'
        }
        (
            Start-CliProcess `
                -FilePath "$env:SYSTEMROOT/System32/cmd.exe" `
                -ArgumentList '/c "echo hello"' `
                *>&1
        ) -join ', ' | Should -Match ([Regex]::Escape('Start CLI Process'))
        if ($env:AGENT_JOBNAME -eq 'PesterTest') {
            $env:AGENT_JOBNAME = $null
        }
    }

    It 'should not throw if there is no process to start' {
        { Get-ChildItem -Filter '*.exe' | Start-CliProcess } | Should -Not -Throw
    }

    It 'should output a single error when an error is multiple lines' {
        {
            Start-CliProcess `
                -FilePath "$env:SYSTEMROOT/System32/cmd.exe" `
                -ArgumentList '/c "echo hello 1>&2 && echo world 1>&2"' `
                -PassThru `
                -ErrorAction Stop
        } | Should -Throw '*world*'
    }

    AfterAll {
        Write-Progress -Activity 'Start CLI Process' -Completed
    }
}