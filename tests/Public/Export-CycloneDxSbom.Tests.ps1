Describe 'CycloneDX export' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        . $PSScriptRoot/../../src/Public/Import-CycloneDxSbom.ps1
        . $PSScriptRoot/../../src/Public/Export-CycloneDxSbom.ps1
        $Script:SetContentCommand = Get-Command Set-Content -CommandType Cmdlet
        $Script:Validator = (
            Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1
        ).Source
    }

    BeforeEach {
        $Script:CaseDirectory = New-Item -Path (Join-Path $TestDrive ([Guid]::NewGuid())) -ItemType Directory
        $Script:Destination = Join-Path $CaseDirectory.FullName 'output [1] with spaces.cdx.json'
        $Script:Json = '{"bomFormat":"CycloneDX","specVersion":"1.6","version":1}'
        $Script:ValidatedPath = $null
        $Script:ValidatedJson = $null
        $Script:TemporaryPaths = @()
        Mock Invoke-NativeCommand {
            $Script:ValidatedPath = $ArgumentList[2]
            $Script:ValidatedJson = Get-Content -LiteralPath $ValidatedPath -Raw -Encoding UTF8
            'BOM validated successfully.'
        }
        Mock New-TemporaryFile {
            $file = New-Item -Path (Join-Path $TestDrive ([Guid]::NewGuid().ToString('N') + '.tmp')) -ItemType File
            $Script:TemporaryPaths += $file.FullName
            $file
        }
    }

    AfterEach {
        foreach ($path in $TemporaryPaths) {
            $path | Should -Not -Exist
        }
        @(Get-ChildItem -LiteralPath $CaseDirectory.FullName -Filter '.sbom-*.tmp' -Force).Count | Should -Be 0
    }

    It 'returns one file containing the exact validated JSON text' {
        $result = @(Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator)

        $result.Count | Should -Be 1
        $result[0] | Should -BeOfType ([System.IO.FileInfo])
        $result[0].FullName | Should -Be $Destination
        (Get-Content -LiteralPath $Destination -Raw -Encoding UTF8) | Should -BeExactly $Json
        $ValidatedJson | Should -BeExactly $Json
        $ValidatedPath | Should -Not -Be $Destination
        Should -Invoke Invoke-NativeCommand -Exactly 1 -ParameterFilter {
            $FilePath -eq $Validator -and $ArgumentList[6] -eq 'v1_6' -and
            $ArgumentList[7] -eq '--fail-on-errors'
        }
    }

    It 'preserves whitespace and non-ASCII text' {
        $name = ('Caf' + [Char]0xE9)
        $Json = @"
{
  "bomFormat": "CycloneDX", "specVersion": "1.6", "version": 1,
  "metadata": {"component": {"type": "application", "name": "$name"}}
}
"@

        $null = Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator

        (Get-Content -LiteralPath $Destination -Raw -Encoding UTF8) | Should -BeExactly $Json
        $ValidatedJson | Should -BeExactly $Json
    }

    It 'resolves a filesystem PSDrive destination' {
        $result = Export-CycloneDxSbom -Json $Json -Path 'TestDrive:/document.cdx.json' -ValidatorPath $Validator

        $result.FullName | Should -Be (Join-Path $TestDrive 'document.cdx.json')
    }

    It 'resolves a relative destination from the PowerShell location' {
        Push-Location -LiteralPath $TestDrive
        try {
            $result = Export-CycloneDxSbom -Json $Json -Path 'relative.cdx.json' -ValidatorPath $Validator
        }
        finally {
            Pop-Location
        }
        $result.FullName | Should -Be (Join-Path $TestDrive 'relative.cdx.json')
    }

    It 'refuses an existing destination without Force before validation' {
        Set-Content -LiteralPath $Destination -Value 'existing' -NoNewline

        { Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator } |
            Should -Throw '*already exists*'

        (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'existing'
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }

    It 'replaces an existing destination only after validation' {
        Set-Content -LiteralPath $Destination -Value 'existing' -NoNewline
        Mock Invoke-NativeCommand {
            (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'existing'
        }

        $result = Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator -Force

        $result.FullName | Should -Be $Destination
        (Get-Content -LiteralPath $Destination -Raw -Encoding UTF8) | Should -BeExactly $Json
    }

    It 'does not overwrite a file created during validation without Force' {
        Mock Invoke-NativeCommand {
            Set-Content -LiteralPath $Destination -Value 'concurrent writer' -NoNewline
        }

        { Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator } | Should -Throw

        (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'concurrent writer'
    }

    It 'preserves the destination after a validator failure' {
        Set-Content -LiteralPath $Destination -Value 'existing' -NoNewline
        Mock Invoke-NativeCommand { throw 'Schema validation failed.' }

        { Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator -Force } |
            Should -Throw '*Schema validation failed*'

        (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'existing'
    }

    It 'does not create the destination after a validator failure' {
        Mock Invoke-NativeCommand { throw 'Schema validation failed.' }

        { Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator } |
            Should -Throw '*Schema validation failed*'

        $Destination | Should -Not -Exist
    }

    It 'preserves the destination and cleans up after a staging failure' {
        Set-Content -LiteralPath $Destination -Value 'existing' -NoNewline
        Mock Set-Content {
            & $Script:SetContentCommand -LiteralPath $LiteralPath -Value $Value -NoNewline -Encoding UTF8
        }
        Mock Set-Content { throw 'Staging write failed.' } -ParameterFilter {
            (Split-Path -Path $LiteralPath -Leaf) -like '.sbom-*.tmp'
        }

        { Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator -Force } |
            Should -Throw '*Staging write failed*'

        (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'existing'
    }

    It 'honors WhatIf even with Force' {
        Set-Content -LiteralPath $Destination -Value 'existing' -NoNewline

        $result = @(Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator -Force -WhatIf)

        $result.Count | Should -Be 0
        (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'existing'
        Should -Invoke Invoke-NativeCommand -Exactly 0
        Should -Invoke New-TemporaryFile -Exactly 0
    }

    It 'does not create a new destination under WhatIf' {
        $result = @(Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator -WhatIf)

        $result.Count | Should -Be 0
        $Destination | Should -Not -Exist
        Should -Invoke Invoke-NativeCommand -Exactly 0
        Should -Invoke New-TemporaryFile -Exactly 0
    }

    It 'rejects a directory destination' {
        { Export-CycloneDxSbom -Json $Json -Path $TestDrive -ValidatorPath $Validator -Force } |
            Should -Throw '*filesystem file*'
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }

    It 'rejects a non-filesystem provider' {
        { Export-CycloneDxSbom -Json $Json -Path 'Env:JBUTILS_TEST_SBOM' -ValidatorPath $Validator } |
            Should -Throw '*filesystem file*'
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }

    It 'does not create a missing parent directory' {
        $parent = Join-Path $TestDrive 'missing-parent'

        { Export-CycloneDxSbom -Json $Json -Path (Join-Path $parent 'document.json') -ValidatorPath $Validator } |
            Should -Throw

        $parent | Should -Not -Exist
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }

    It 'preserves the destination when the validator is missing' {
        Set-Content -LiteralPath $Destination -Value 'existing' -NoNewline

        { Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath 'missing-sbom-test-tool' -Force } |
            Should -Throw

        (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'existing'
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }


    It 'writes into a directory whose name contains wildcard characters' {
        $parent = New-Item -Path (Join-Path $CaseDirectory.FullName 'output [1]') -ItemType Directory
        $path = Join-Path $parent.FullName 'document.cdx.json'

        $result = Export-CycloneDxSbom -Json $Json -Path $path -ValidatorPath $Validator

        $result.FullName | Should -Be $path
        (Get-Content -LiteralPath $path -Raw -Encoding UTF8) | Should -BeExactly $Json
    }

    It 'cleans up when the destination becomes a directory during validation' {
        Mock Invoke-NativeCommand {
            $null = New-Item -Path $Destination -ItemType Directory
        }

        { Export-CycloneDxSbom -Json $Json -Path $Destination -ValidatorPath $Validator } | Should -Throw

        (Get-Item -LiteralPath $Destination).PSIsContainer | Should -BeTrue
        @(Get-ChildItem -LiteralPath $Destination -Force).Count | Should -Be 0
    }

    It 'rejects <Label> without changing the destination' -ForEach @(
        @{ Label = 'invalid JSON'; Value = '{"bomFormat":' }
        @{ Label = 'an array'; Value = '[{"bomFormat":"CycloneDX","specVersion":"1.6"}]' }
        @{ Label = 'SPDX'; Value = '{"spdxVersion":"SPDX-2.2"}' }
        @{ Label = 'a different CycloneDX version'; Value = '{"bomFormat":"CycloneDX","specVersion":"1.5"}' }
    ) {
        Set-Content -LiteralPath $Destination -Value 'existing' -NoNewline

        { Export-CycloneDxSbom -Json $Value -Path $Destination -ValidatorPath $Validator -Force } | Should -Throw

        (Get-Content -LiteralPath $Destination -Raw) | Should -BeExactly 'existing'
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }
}
