Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Get-UsernameSID.ps1
        class mock_ntaccount {
            [System.Object]Translate($var) {
                return [PSCustomObject]@{
                    Value = 'mockvalue'
                }
            }
            mock_ntaccount() { }
        }

        Mock 'New-Object' { New-Object 'mock_ntaccount' } `
            -ParameterFilter {
                $TypeName -and
                $TypeName -eq 'System.Security.Principal.NTAccount'
            }
    }

    It 'should return the nt user account sid associated with the nt account name' {
        $result = Get-UsernameSID 'MockAccountName'
        $result | Should -Be 'mockvalue'
    }
}
