Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/ConvertFrom-EncryptedSecureString.ps1
    }

    It 'should successfully convert a SecureString' {
        $secureString = ConvertTo-SecureString -String 'Ins3cur3$tring' -AsPlainText -Force
        $secureString | ConvertFrom-EncryptedSecureString | Should -Be 'Ins3cur3$tring'
    }
}