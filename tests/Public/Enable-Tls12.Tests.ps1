Describe 'TLS configuration' -Tag 'Unit' {
    BeforeAll {
        . "$PSScriptRoot/../../src/Public/Enable-Tls12.ps1"
        . "$PSScriptRoot/../../src/Public/Test-IsAdmin.ps1"
        . "$PSScriptRoot/../../src/Public/Get-PSVersion.ps1"
        . "$PSScriptRoot/../../src/Public/Test-PSEnvironment.ps1"
        $script:originalProtocol = [Net.ServicePointManager]::SecurityProtocol
    }

    BeforeEach {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SystemDefault
        Mock Test-IsAdmin { $true }
        Mock New-Item {}
        Mock New-ItemProperty {}
        Mock Start-Process {}
    }

    AfterAll {
        [Net.ServicePointManager]::SecurityProtocol = $script:originalProtocol
    }

    It 'sets TLS 1.2 in the current process without persisting it' {
        Enable-Tls12
        [Net.ServicePointManager]::SecurityProtocol | Should -Be Tls12
        Should -Invoke New-Item -Times 0
        Should -Invoke Start-Process -Times 0
    }

    It 'rejects persistence without administrator privileges before modifying the registry' {
        Mock Test-IsAdmin { $false }
        { Enable-Tls12 -Persist } | Should -Throw '*not running with admin*'
        Should -Invoke New-Item -Times 0
        Should -Invoke New-ItemProperty -Times 0
        Should -Invoke Start-Process -Times 0
    }

    It 'configures client and server registry values and both .NET registry views' {
        Enable-Tls12 -Persist
        Should -Invoke New-Item -Times 2 -Exactly -ParameterFilter { $Path -like 'HKLM:*TLS 1.2*' }
        Should -Invoke New-ItemProperty -Times 2 -Exactly -ParameterFilter {
            $Name -eq 'DisabledByDefault' -and $Value -eq 0 -and $PropertyType -eq 'DWord'
        }
        Should -Invoke New-ItemProperty -Times 2 -Exactly -ParameterFilter {
            $Name -eq 'Enabled' -and $Value -eq 1 -and $PropertyType -eq 'DWord'
        }
        Should -Invoke Start-Process -Times 16 -Exactly -ParameterFilter { $FilePath -eq 'reg' }
        Should -Invoke Start-Process -Times 8 -Exactly -ParameterFilter { $ArgumentList -contains '/reg:32' }
        Should -Invoke Start-Process -Times 8 -Exactly -ParameterFilter { $ArgumentList -contains '/reg:64' }
    }
}
