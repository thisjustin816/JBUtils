BeforeAll {
    . "$PSScriptRoot/../../src/Public/Get-PatPSCredential.ps1"
}

Describe 'Unit Tests' {
    It 'should create a PSCredential with specified username and PAT' {
        $pat = 'test-pat-token'
        $username = 'test-user'

        $result = Get-PatPSCredential -Pat $pat -Username $username

        $result | Should -BeOfType [PSCredential]
        $result.Username | Should -Be $username
        # Convert secure string back to plain text to verify
        $networkCred = $result.GetNetworkCredential()
        $networkCred.Password | Should -Be $pat
    }

    It 'should use default username if none specified' {
        $pat = 'test-pat-token'

        $result = Get-PatPSCredential -Pat $pat

        $result | Should -BeOfType [PSCredential]
        $result.Username | Should -Be 'PAT'
        # Convert secure string back to plain text to verify
        $networkCred = $result.GetNetworkCredential()
        $networkCred.Password | Should -Be $pat
    }

    It 'should use SYSTEM_ACCESSTOKEN if PAT is not provided' {
        $env:SYSTEM_ACCESSTOKEN = 'test-system-token'
        $result = Get-PatPSCredential
        $networkCred = $result.GetNetworkCredential()
        $networkCred.Password | Should -Be 'test-system-token'
        $env:SYSTEM_ACCESSTOKEN = $null
    }

    It 'should throw if PAT is not provided and SYSTEM_ACCESSTOKEN is not set' {
        $env:SYSTEM_ACCESSTOKEN = $null
        { Get-PatPSCredential } | Should -Throw
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    It 'should create a working credential that can be used with basic auth' {
        $pat = 'test-pat-token'
        $username = 'test-user'

        $cred = Get-PatPSCredential -Pat $pat -Username $username

        # Convert to base64 like it would be used in basic auth
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("$($cred.Username):$($cred.GetNetworkCredential().Password)")
        $base64 = [System.Convert]::ToBase64String($bytes)

        # Check base64 matches expected value
        $expectedBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$username`:$pat"))
        $base64 | Should -Be $expectedBase64
    }
}
