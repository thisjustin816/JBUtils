Describe 'CycloneDX import' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        . $PSScriptRoot/../../src/Public/Import-CycloneDxSbom.ps1
        $Script:Validator = (
            Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1
        ).Source
    }

    BeforeEach {
        $Script:SnapshotPath = $null
        $Script:SnapshotJson = $null
        $Script:InputPath = Join-Path $TestDrive 'sample [1] with spaces.cdx.json'
        $Script:Json = @'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "version": 1,
  "metadata": {
    "component": {
      "type": "application", "name": "Example", "version": "1.2.3", "bom-ref": "root",
      "supplier": {"name": "Example Supplier"}, "licenses": [{"license": {"id": "MIT"}}]
    }
  },
  "components": [
    {"type": "library", "name": "Example.Library", "version": "2.0.0",
     "bom-ref": "lib", "purl": "pkg:nuget/Example.Library@2.0.0"}
  ],
  "dependencies": [{"ref": "root", "dependsOn": ["lib"]}, {"ref": "lib", "dependsOn": []}],
  "compositions": [{"aggregate": "complete", "assemblies": ["root"]}]
}
'@
        Set-Content -LiteralPath $InputPath -Value $Json -Encoding UTF8
        Mock Invoke-NativeCommand {
            $Script:SnapshotPath = $ArgumentList[2]
            $Script:SnapshotJson = Get-Content -LiteralPath $Script:SnapshotPath -Raw -Encoding UTF8
            'BOM validated successfully.'
        }
    }

    It 'returns only the document and preserves generic package and completeness data' {
        $result = @(Import-CycloneDxSbom -Path $InputPath -ValidatorPath $Validator)

        $result.Count | Should -Be 1
        $result[0].components[0].purl | Should -Be 'pkg:nuget/Example.Library@2.0.0'
        $result[0].compositions[0].aggregate | Should -Be 'complete'
        $result[0].metadata.component.licenses[0].license.id | Should -Be 'MIT'
        $result[0].metadata.component.supplier.name | Should -Be 'Example Supplier'
        Should -Invoke Invoke-NativeCommand -Exactly 1 -ParameterFilter {
            $FilePath -eq $Validator -and $ArgumentList[0] -eq 'validate' -and
            $ArgumentList[1] -eq '--input-file' -and $ArgumentList[3] -eq '--input-format' -and
            $ArgumentList[4] -eq 'json' -and $ArgumentList[5] -eq '--input-version' -and
            $ArgumentList[6] -eq 'v1_6' -and $ArgumentList[7] -eq '--fail-on-errors'
        }
    }

    It 'validates a snapshot and removes it after success without changing the input' {
        $before = Get-FileHash -LiteralPath $InputPath
        $null = Import-CycloneDxSbom -Path $InputPath -ValidatorPath $Validator

        $SnapshotPath | Should -Not -BeNullOrEmpty
        $SnapshotPath | Should -Not -Be $InputPath
        $SnapshotPath | Should -Not -Exist
        $SnapshotJson.Trim() | Should -Be $Json.Trim()
        (Get-FileHash -LiteralPath $InputPath).Hash | Should -Be $before.Hash
    }

    It 'returns the snapshot content when the original changes during validation' {
        Mock Invoke-NativeCommand {
            Set-Content -LiteralPath $InputPath -Value '{}' -Encoding UTF8
        }

        $result = Import-CycloneDxSbom -Path $InputPath -ValidatorPath $Validator

        $result.metadata.component.name | Should -Be 'Example'
    }

    It 'preserves UTF-8 names in the validated snapshot' {
        $name = ('Caf' + [Char]0xE9)
        Set-Content -LiteralPath $InputPath -Value $Json.Replace('Example Supplier', $name) -Encoding UTF8

        $result = Import-CycloneDxSbom -Path $InputPath -ValidatorPath $Validator

        $result.metadata.component.supplier.name | Should -Be $name
        ($SnapshotJson | ConvertFrom-Json).metadata.component.supplier.name | Should -Be $name
    }

    It 'terminates on validator failure and removes the snapshot' {
        Mock Invoke-NativeCommand {
            $Script:SnapshotPath = $ArgumentList[2]
            throw 'CycloneDX schema validation failed. Exit code: 1'
        }

        { Import-CycloneDxSbom -Path $InputPath -ValidatorPath $Validator } |
            Should -Throw '*schema validation failed*'
        $SnapshotPath | Should -Not -BeNullOrEmpty
        $SnapshotPath | Should -Not -Exist
    }

    It 'rejects unsupported or malformed input <Label> before invoking a validator' -ForEach @(
        @{ Label = 'SPDX'; Content = '{"spdxVersion":"SPDX-2.2"}' }
        @{ Label = 'another version'; Content = '{"bomFormat":"CycloneDX","specVersion":"1.5"}' }
        @{ Label = 'wrong format case'; Content = '{"bomFormat":"cyclonedx","specVersion":"1.6"}' }
        @{ Label = 'missing version'; Content = '{"bomFormat":"CycloneDX"}' }
        @{ Label = 'invalid JSON'; Content = '{"bomFormat":' }
        @{ Label = 'array'; Content = '[{"bomFormat":"CycloneDX","specVersion":"1.6"}]' }
        @{ Label = 'empty'; Content = '' }
        @{ Label = 'null'; Content = 'null' }
    ) {
        Set-Content -LiteralPath $InputPath -Value $Content -Encoding UTF8

        { Import-CycloneDxSbom -Path $InputPath -ValidatorPath $Validator } | Should -Throw
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }

    It 'rejects a directory' {
        { Import-CycloneDxSbom -Path $TestDrive -ValidatorPath $Validator } | Should -Throw '*filesystem file*'
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }

    It 'rejects a missing document' {
        { Import-CycloneDxSbom -Path (Join-Path $TestDrive 'absent.json') -ValidatorPath $Validator } |
            Should -Throw
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }

    It 'uses the first executable when PATH contains multiple installations' {
        Mock Get-Command {
            [PSCustomObject]@{ Source = $Script:Validator }
            [PSCustomObject]@{ Source = 'unused-validator' }
        } -ParameterFilter { $Name -eq 'cyclonedx-cli' -and $CommandType -eq 'Application' }

        $result = Import-CycloneDxSbom -Path $InputPath

        $result.bomFormat | Should -Be 'CycloneDX'
        Should -Invoke Invoke-NativeCommand -Exactly 1 -ParameterFilter { $FilePath -eq $Script:Validator }
    }
    It 'fails closed when the CLI is missing' {
        { Import-CycloneDxSbom -Path $InputPath -ValidatorPath 'missing-cyclonedx-test-executable' } |
            Should -Throw
        Should -Invoke Invoke-NativeCommand -Exactly 0
    }
}
