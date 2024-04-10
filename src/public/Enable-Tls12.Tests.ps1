Describe 'Unit/Integration Tests' {
    BeforeDiscovery {
        $global:isAdmin = Test-IsAdmin
    }

    BeforeAll {
        . $PSScriptRoot/Enable-Tls12.ps1
        . $PSScriptRoot/Test-IsAdmin.ps1
        . $PSScriptRoot/Get-PSVersion.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1
        . $PSScriptRoot/Start-Timeout
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SystemDefault
    }

    It 'should change TLS of the current session to 1.2' {
        Enable-Tls12
        [Net.ServicePointManager]::SecurityProtocol | Should -Be Tls12
    }

    Context 'When running in a non-admin console' {
        BeforeAll {
            Mock Test-IsAdmin { $false }
            Mock Start-Process
        }

        It 'should throw when using -Persist' {
            { Enable-Tls12 -Persist } | Should -Throw
            Assert-MockCalled Start-Process -Times 0
        }
    }

    Context 'When there have been no registry modifications' -Skip:(!$global:isAdmin) {
        BeforeAll {
            Mock Start-Process
        }

        It 'should modify registry values if Persist is used' {
            Enable-Tls12 -Persist
            Assert-MockCalled Start-Process -Times 16 -Exactly
        }
    }

    It 'should modify all settings without an error' -Skip:(!$global:isAdmin) {
        { Enable-Tls12 -Persist } | Should -Not -Throw
    }
}
