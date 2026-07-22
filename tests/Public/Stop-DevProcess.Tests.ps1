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
            Start-Process `
                -FilePath "$env:SYSTEMROOT/System32/cmd.exe" `
                -ArgumentList "/c $env:SYSTEMROOT/System32/timeout.exe /t 60"
            Start-Sleep -Milliseconds 1000
        }
    }

    It 'should kill a process without prompting if using Required' -Skip:(-not $script:isAdmin) {
        Start-Timeout
        Stop-DevProcess -Required timeout
        Get-Process timeout -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'should kill the parent and child processes' -Skip:(-not $script:isAdmin) {
        Start-Timeout
        Stop-DevProcess -Required cmd
        Get-Process cmd -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Process timeout -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    Context 'When using Optional and confirming' {
        BeforeAll {
            Mock Read-Host { 'y' }
        }

        It 'should kill the process' -Skip:(-not $script:isAdmin) {
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
