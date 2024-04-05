Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../private/Invoke-Timeout.ps1
        . $PSScriptRoot/Start-Timeout.ps1
        . $PSScriptRoot/Test-IsNonInteractiveShell.ps1

        Mock Invoke-Timeout {
            Write-Output -InputObject "Waiting for $Seconds seconds"
            Start-Sleep -Seconds 3
        }

        Mock -ParameterFilter { $NoBreakSwitch -match 'nobreak' } Invoke-Timeout {
            Write-Output -InputObject 'press CTRL+C to quit'
        }

        Mock Test-IsNonInteractiveShell {
            $false
        }
    }

    It 'should wait for the specified time' {
        $start = Get-Date
        Start-Timeout -Seconds 3 |
            Where-Object -FilterScript { ![String]::IsNullOrEmpty($_) } |
            Should -Match 'Waiting for 3 seconds'

        (( Get-Date ) - $start).TotalSeconds |
            Should -BeGreaterOrEqual 3
    }

    It 'should not allow pressing a key to continue when specified' {
        Start-Timeout -NoBreak |
            Where-Object -FilterScript { ![String]::IsNullOrEmpty($_) } |
            Should -Match "$([Regex]::Escape('press CTRL+C to quit'))"
    }

    Context 'when the shell is non-interactive' {
        BeforeAll {
            Mock Test-IsNonInteractiveShell {
                $true
            }
        }

        It 'should not use timeout.exe' {
            Start-Timeout -Seconds 1
            Should -Not -Invoke Invoke-Timeout
        }
    }
}
