Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Set-JsonFile.ps1
    }

    It 'should write the object as JSON to the given path' {
        $path = Join-Path -Path $TestDrive -ChildPath 'out.json'
        [PSCustomObject]@{ Name = 'test'; Count = 3 } | Set-JsonFile -Path $path

        $path | Should -Exist
        $written = Get-Content -Path $path -Raw | ConvertFrom-Json
        $written.Name | Should -Be 'test'
        $written.Count | Should -Be 3
    }

    It 'should not write anything with -WhatIf' {
        $path = Join-Path -Path $TestDrive -ChildPath 'whatif.json'
        [PSCustomObject]@{ Name = 'test' } | Set-JsonFile -Path $path -WhatIf
        $path | Should -Not -Exist
    }
}
