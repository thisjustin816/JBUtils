Describe 'Unit/Integration Tests' {
    BeforeAll {
        . $PSScriptRoot/Enable-Tls12.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1
        . $PSScriptRoot/Start-Timeout
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SystemDefault

        try {
            Test-PSEnvironment -CheckAdmin $true
            $script:isAdmin = $true
        }
        catch {
            $script:isAdmin = $false
        }
    }

    It 'should change TLS of the current session to 1.2' {
        Enable-Tls12
        [Net.ServicePointManager]::SecurityProtocol | Should -Be Tls12
    }

    Context 'When running in a non-admin console' {
        BeforeAll {
            Mock Test-PSEnvironment { throw }
            Mock Start-Process
        }

        It 'should throw when using -Persist' {
            { Enable-Tls12 -Persist } | Should -Throw
            Assert-MockCalled Start-Process -Times 0
        }
    }

    Context 'When there have been no registry modifications' -Skip:(!$script:isAdmin) {
        BeforeAll {
            Mock Start-Process
        }

        It 'should modify registry values if Persist is used' {
            Enable-Tls12 -Persist
            Assert-MockCalled Start-Process -Times 16 -Exactly
        }
    }

    It 'should modify all settings without an error' -Skip:(!$script:isAdmin) {
        { Enable-Tls12 -Persist } | Should -Not -Throw
    }
}
