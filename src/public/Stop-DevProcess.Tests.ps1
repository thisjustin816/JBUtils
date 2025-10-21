Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/Stop-ProcessTree.ps1
        . $PSScriptRoot/Stop-DevProcess.ps1
        . $PSScriptRoot/Test-IsAdmin.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1
        . $PSScriptRoot/Get-PSVersion.ps1

        # Mock process operations to test without admin rights
        Mock Stop-Process { return $true }
        Mock Wait-Process { return $true }
        Mock Test-PSEnvironment { return $true }

        # Use script scope instead of global
        $script:processExists = $false
        Mock Get-Process {
            if ($script:processExists) {
                $obj = [PSCustomObject]@{
                    Id = 123
                    ProcessName = $Name
                    Product = $null
                }
                $obj | Add-Member -MemberType ScriptMethod -Name "Stop" -Value { return $true }
                return $obj
            }
            return $null
        }        <#
        .SYNOPSIS
        Dummy function in order to mock it without the whole module

        #>
        function Initialize-TimeoutProcess {
            [CmdletBinding(SupportsShouldProcess)]
            param()

            if ($PSCmdlet.ShouldProcess("timeout.exe", "Start process")) {
                Start-Process `
                    -FilePath "$env:SYSTEMROOT/System32/cmd.exe" `
                    -ArgumentList "/c $env:SYSTEMROOT/System32/timeout.exe /t 60"
                Start-Sleep -Milliseconds 500
            }
        }
    }

    It 'should kill a process without prompting if using Required' {
        $script:processExists = $true
        Stop-DevProcess -Required timeout
        Should -Invoke Stop-Process -Times 1
        $script:processExists = $false
    }

    It 'should kill the parent and child processes' {
        $script:processExists = $true
        Stop-DevProcess -Required cmd
        Should -Invoke Stop-Process -Times 2 # Once for cmd, once for timeout
        $script:processExists = $false
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
            $script:processExists = $true
            # Process is simulated through mocking
            Stop-DevProcess -Optional timeout
            Get-Process timeout -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}