Describe 'OS credential store' -Tag 'Unit' {
    BeforeAll {
        Get-ChildItem -Path "$PSScriptRoot/../../src/*/*OsCredential*.ps1" | ForEach-Object { . $_.FullName }
        $Script:PwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    }

    BeforeEach {
        $Script:CapturedStart = $null
        $Script:CapturedInput = $null
        Mock Get-Command { [PSCustomObject]@{ Source = $PwshPath } } -ParameterFilter { $Name -eq 'git' }
        Mock Invoke-OsCredentialProtocol {
            $Script:CapturedStart = $StartInfo
            $Script:CapturedInput = $InputText
            "username=developer`npassword=synthetic-value`n"
        }
    }

    It 'returns a credential object without writing its password to output' {
        $result = Get-OsCredential -Name 'sample-token' -UserName 'developer'
        $result | Should -BeOfType PSCredential
        $result.GetNetworkCredential().Password | Should -Be 'synthetic-value'
        $CapturedStart.Arguments | Should -Be 'credential-manager get'
        $CapturedInput | Should -Match 'protocol=jbutils'
    }

    It 'uses only the first resolved executable when multiple Git installations exist' {
        Mock Get-Command {
            [PSCustomObject]@{ Source = $PwshPath }
            [PSCustomObject]@{ Source = 'another-git' }
        } -ParameterFilter { $Name -eq 'git' }
        $null = Get-OsCredential -Name 'sample-token' -UserName 'developer'
        $CapturedStart.FileName | Should -Be $PwshPath
    }
    It 'binds a native OS store and disables inherited tracing and authentication prompts' {
        $priorStore = $env:GCM_CREDENTIAL_STORE
        $priorTrace = $env:GCM_TRACE_SECRETS
        try {
            $env:GCM_CREDENTIAL_STORE = 'plaintext'
            $env:GCM_TRACE_SECRETS = 'true'
            $null = Get-OsCredential -Name 'sample-token' -UserName 'developer' -Namespace 'example-app'
            $expectedStore = if ($PSVersionTable.Platform -ne 'Unix') { 'wincredman' }
            elseif ($IsMacOS) { 'keychain' }
            else { 'secretservice' }
            $CapturedStart.EnvironmentVariables['GCM_CREDENTIAL_STORE'] | Should -Be $expectedStore
            $CapturedStart.EnvironmentVariables['GCM_TRACE_SECRETS'] | Should -BeNullOrEmpty
            $CapturedStart.EnvironmentVariables['GCM_TRACE'] | Should -Be '0'
            $CapturedStart.EnvironmentVariables['GCM_INTERACTIVE'] | Should -Be 'never'
            $CapturedStart.EnvironmentVariables['GCM_PROVIDER'] | Should -Be 'generic'
            $CapturedStart.EnvironmentVariables['GCM_NAMESPACE'] | Should -Be 'example-app'
            $env:GCM_CREDENTIAL_STORE | Should -Be 'plaintext'
        }
        finally {
            $env:GCM_CREDENTIAL_STORE = $priorStore
            $env:GCM_TRACE_SECRETS = $priorTrace
        }
    }

    It 'passes a supplied password through stdin and emits no stored credential' {
        $credential = [PSCredential]::new('developer', (ConvertTo-SecureString 'synthetic-value' -AsPlainText -Force))
        $result = @(Set-OsCredential -Name 'sample-token' -Credential $credential -Confirm:$false)
        $result.Count | Should -Be 0
        $CapturedStart.Arguments | Should -Be 'credential-manager store'
        $CapturedStart.Arguments | Should -Not -Match 'synthetic-value'
        $CapturedInput | Should -Match 'password=synthetic-value'
    }

    It 'does not start a credential process under WhatIf' {
        $credential = [PSCredential]::new('developer', (ConvertTo-SecureString 'synthetic-value' -AsPlainText -Force))
        Set-OsCredential -Name 'sample-token' -Credential $credential -WhatIf
        Remove-OsCredential -Name 'sample-token' -UserName 'developer' -WhatIf
        Should -Invoke Invoke-OsCredentialProtocol -Times 0
    }

    It 'removes only the named credential and account' {
        Remove-OsCredential -Name 'sample-token' -UserName 'developer' -Confirm:$false
        $CapturedStart.Arguments | Should -Be 'credential-manager erase'
        $CapturedInput | Should -Match "path=sample-token`nusername=developer"
        $CapturedInput | Should -Not -Match 'password='
    }

    It 'rejects newline injection in a credential before starting a process' {
        $secret = ConvertTo-SecureString "value`nusername=other" -AsPlainText -Force
        $credential = [PSCredential]::new('developer', $secret)
        { Set-OsCredential -Name 'sample-token' -Credential $credential -Confirm:$false } |
            Should -Throw '*single line*'
        Should -Invoke Invoke-OsCredentialProtocol -Times 0
    }

    It 'rejects newline suffixes in entry names and namespaces before starting a process' {
        { Get-OsCredential -Name "sample-token`n" -UserName 'developer' } | Should -Throw
        { Get-OsCredential -Name 'sample-token' -UserName 'developer' -Namespace "app`n" } | Should -Throw
        Should -Invoke Invoke-OsCredentialProtocol -Times 0
    }
    It 'rejects a different returned account' {
        Mock Invoke-OsCredentialProtocol { "username=other`npassword=synthetic-value`n" }
        { Get-OsCredential -Name 'sample-token' -UserName 'developer' } | Should -Throw '*requested account*'
    }

    It 'does not include native error output in exceptions' {
        Mock Invoke-OsCredentialProtocol { throw 'synthetic-value leaked by a failing helper' }
        $failure = try { Get-OsCredential -Name 'sample-token' -UserName 'developer' } catch { $_ }
        $failure.Exception.Message | Should -Not -Match 'synthetic-value'
        $failure.Exception.Message | Should -Match 'OS credential store'
    }
}

Describe 'Credential subprocess isolation' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Private/Invoke-OsCredentialProtocol.ps1
        $Script:PwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    }

    It 'captures stdout privately and passes stdin without command-line interpolation' {
        $code = '$line = [Console]::ReadLine(); [Console]::WriteLine($line)'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $start = [Diagnostics.ProcessStartInfo]::new($PwshPath, "-NoProfile -NonInteractive -EncodedCommand $encoded")
        $result = Invoke-OsCredentialProtocol -StartInfo $start -InputText 'synthetic-value'
        $result.Trim() | Should -Be 'synthetic-value'
    }

    It 'keeps startup failures sanitized for strict-mode callers' {
        Set-StrictMode -Version Latest
        $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $TestDrive 'missing-executable'))
        { Invoke-OsCredentialProtocol -StartInfo $start -InputText 'request' } |
            Should -Throw '*OS credential store*'
    }

    It 'rejects a failed helper without exposing stdout or stderr' {
        $code = '[Console]::WriteLine("synthetic-value"); [Console]::Error.WriteLine("synthetic-value"); exit 7'
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $start = [Diagnostics.ProcessStartInfo]::new($PwshPath, "-NoProfile -NonInteractive -EncodedCommand $encoded")
        $failure = try { Invoke-OsCredentialProtocol -StartInfo $start -InputText 'request' } catch { $_ }
        $failure.Exception.Message | Should -Not -Match 'synthetic-value'
        $failure.Exception.Message | Should -Match 'OS credential store'
    }
}
