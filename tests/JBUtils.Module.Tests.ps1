# Pester declares parameters in lowercase (e.g. -name on It).
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCorrectCasing', '')]
param ()

Describe 'Module Validation' {
    BeforeAll {
        $script:builtManifest = Get-ChildItem -Path "$PSScriptRoot/../out/JBUtils" -Filter 'JBUtils.psd1' -Recurse -ErrorAction SilentlyContinue |
            Sort-Object -Property FullName -Descending |
            Select-Object -First 1
    }

    Context 'built module' {
        It 'should have been built before running this test' {
            $script:builtManifest | Should -Not -BeNullOrEmpty -Because 'Build-PSModule must run before Module Validation tests'
        }

        It 'should preserve Windows PowerShell compatibility metadata' {
            $manifest = Import-PowerShellDataFile -Path $script:builtManifest.FullName
            $manifest.PowerShellVersion | Should -Be '5.1'
            $manifest.CompatiblePSEditions | Should -Contain 'Desktop'
            $manifest.CompatiblePSEditions | Should -Contain 'Core'
        }

        It 'should not contain Pester test syntax' {
            $builtScript = Join-Path -Path $script:builtManifest.DirectoryName -ChildPath 'JBUtils.psm1'
            $builtScript | Should -Not -FileContentMatch '^Describe '
        }

        It 'should not retain source-layout dot-sourcing' {
            $builtScript = Join-Path -Path $script:builtManifest.DirectoryName -ChildPath 'JBUtils.psm1'
            $builtScript | Should -Not -FileContentMatch '\$PSScriptRoot/\.\./(?:Public|Private)'
        }

        It 'should produce a publishable package' {
            $package = Compress-PSResource `
                -Path $script:builtManifest.DirectoryName `
                -DestinationPath $TestDrive `
                -PassThru `
                -ErrorAction Stop
            $package.FullName | Should -Exist
        }

        It 'should export exactly its own public functions' {
            Get-Module -Name 'JBUtils' -All | Remove-Module -Force -ErrorAction SilentlyContinue
            $module = Import-Module -Name $script:builtManifest.FullName -Force -PassThru

            $expected = @(
                Get-ChildItem -Path "$PSScriptRoot/../src/Public" -Filter '*.ps1' -File |
                    ForEach-Object { $_.BaseName } |
                    Sort-Object
            )

            try {
                @($module.ExportedFunctions.Keys | Sort-Object) | Should -Be $expected
            }
            finally {
                Remove-Module -Name 'JBUtils' -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
