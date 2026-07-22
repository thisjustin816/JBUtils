Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/ConvertTo-Psd1.ps1
    }

    It 'should render scalars' {
        ConvertTo-Psd1 -InputObject $null | Should -BeExactly '$null'
        ConvertTo-Psd1 -InputObject $true | Should -BeExactly '$true'
        ConvertTo-Psd1 -InputObject $false | Should -BeExactly '$false'
        ConvertTo-Psd1 -InputObject 42 | Should -BeExactly '42'
        ConvertTo-Psd1 -InputObject "it's" | Should -BeExactly "'it''s'"
    }

    It 'should render an empty array and an empty hashtable' {
        ConvertTo-Psd1 -InputObject @() | Should -BeExactly '@()'
        ConvertTo-Psd1 -InputObject @{} | Should -BeExactly '@{}'
    }

    It 'should round-trip a nested structure through Import-PowerShellDataFile' {
        $data = @{
            Name         = 'MyModule'
            Tags         = @('PSEdition_Core', 'Windows')
            RequiredModules = @(
                @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
            )
            Nested       = @{ Flag = $true; Count = 3 }
        }

        $rendered = ConvertTo-Psd1 -InputObject $data
        $path = Join-Path -Path $TestDrive -ChildPath 'roundtrip.psd1'
        Set-Content -Path $path -Value $rendered -Encoding utf8NoBOM

        $roundTripped = Import-PowerShellDataFile -Path $path
        $roundTripped.Name | Should -Be 'MyModule'
        $roundTripped.Tags | Should -Be @('PSEdition_Core', 'Windows')
        $roundTripped.RequiredModules[0].ModuleName | Should -Be 'Pester'
        $roundTripped.Nested.Flag | Should -BeTrue
        $roundTripped.Nested.Count | Should -Be 3
    }
}
