Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Private/Get-UsernameSID.ps1
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseConsistentParametersKind', '', Justification = 'PowerShell class methods require inline parameters.'
        )]
        class mock_ntaccount {
            [System.Object]Translate($var) {
                return [PSCustomObject]@{
                    Value = 'mockvalue'
                }
            }
            mock_ntaccount() { }
        }

        Mock 'New-Object' { [mock_ntaccount]::new() } -ParameterFilter {
            $TypeName -eq 'System.Security.Principal.NTAccount'
        }
    }

    It 'should return the nt user account sid associated with the nt account name' {
        $result = Get-UsernameSID 'MockAccountName'
        $result | Should -Be 'mockvalue'
    }
}
