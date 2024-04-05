Describe 'Integration Tests' -Skip:(!$script:isAdmin) {
    BeforeDiscovery {
        $script:isAdmin = try {
            Test-PSEnvironment
            $true
        }
        catch {
            $false
        }
    }

    BeforeAll {
        . $PSScriptRoot/Stop-ProcessTree.ps1
        . $PSScriptRoot/Stop-DevProcess.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1
        . $PSScriptRoot/Get-PSVersion.ps1

        <#
        .SYNOPSIS
        Dummy function in order to mock it without the whole module

        #>
        function Start-Timeout {
            Start-Process `
                -FilePath "$env:SYSTEMROOT/System32/cmd.exe" `
                -ArgumentList "/c $env:SYSTEMROOT/System32/timeout.exe /t 60"
            Start-Sleep -Milliseconds 500
        }
    }

    It 'should kill a process without prompting if using Required' {
        Start-Timeout
        Stop-DevProcess -Required timeout
        Get-Process timeout -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'should kill the parent and child processes' {
        Start-Timeout
        Stop-DevProcess -Required cmd
        Get-Process cmd -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Process timeout -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    Context 'When using Optional and confirming' {
        BeforeAll {
            Mock Read-Host { 'y' }
        }

        It 'should kill the process' {
            Start-Timeout
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
            Start-Timeout
            Stop-DevProcess -Optional timeout
            Get-Process timeout -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}