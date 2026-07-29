Describe 'Integration Tests' {
    BeforeDiscovery {
        . $PSScriptRoot/../../src/Public/Test-IsAdmin.ps1
        $script:isAdmin = Test-IsAdmin
    }

    BeforeAll {
        . $PSScriptRoot/../../src/Public/Stop-ProcessTree.ps1
        . $PSScriptRoot/../../src/Public/Stop-DevProcess.ps1
        . $PSScriptRoot/../../src/Public/Test-IsAdmin.ps1
        . $PSScriptRoot/../../src/Public/Test-PSEnvironment.ps1
        . $PSScriptRoot/../../src/Public/Get-PSVersion.ps1

        <#
        .SYNOPSIS
        Dummy function in order to mock it without the whole module

        #>
        function Start-Timeout {
            $parentProcess = Start-Process `
                -FilePath "$env:SYSTEMROOT/System32/cmd.exe" `
                -ArgumentList "/c $env:SYSTEMROOT/System32/timeout.exe /t 60" `
                -PassThru

            # Wait for the child to exist rather than sleeping a fixed interval. Returning before
            # timeout.exe spawns leaves Stop-DevProcess nothing to enumerate, so it exits without
            # killing anything and the process appears moments later, when the test asserts.
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            while (-not (Get-Process -Name 'timeout' -ErrorAction SilentlyContinue)) {
                if ([DateTime]::UtcNow -gt $deadline) {
                    throw 'timeout.exe did not start within 30 seconds.'
                }
                Start-Sleep -Milliseconds 50
            }

            $parentProcess
        }
    }

    It 'should kill a process without prompting if using Required' -Skip:(-not $script:isAdmin) {
        $null = Start-Timeout
        Stop-DevProcess -Required timeout
        Get-Process timeout -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'should kill the parent and child processes' -Skip:(-not $script:isAdmin) {
        $parentProcess = Start-Timeout
        Stop-DevProcess -Required cmd
        # Asserted against the cmd.exe this test started, not the machine's cmd.exe population. A
        # bare 'Get-Process cmd' claims no cmd.exe exists anywhere, which any shell a CI agent
        # happens to be running falsifies at random.
        $parentProcess.HasExited | Should -BeTrue
        Get-Process timeout -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    Context 'When using Optional and confirming' {
        BeforeAll {
            Mock Read-Host { 'y' }
        }

        It 'should kill the process' -Skip:(-not $script:isAdmin) {
            $null = Start-Timeout
            Stop-DevProcess -Optional timeout
            Get-Process timeout -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }

    Context 'When using Optional and not confirming' {
        BeforeAll {
            Mock Read-Host { 'n' }
        }

        AfterEach {
            Get-Process timeout -ErrorAction SilentlyContinue | Stop-Process -Force -PassThru | Wait-Process
        }

        It 'should not kill the process' {
            $null = Start-Timeout
            Stop-DevProcess -Optional timeout
            Get-Process timeout -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
