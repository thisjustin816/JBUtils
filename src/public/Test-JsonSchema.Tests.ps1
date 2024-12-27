Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/Test-JsonSchema.ps1
        . $PSScriptRoot/Get-PSVersion.ps1
        $script:schema = @'
{
    "type": "object",
    "properties": {
        "name": {
            "type": "string"
        },
        "age": {
            "type": "number"
        }
    },
    "required": ["name", "age"]
}
'@
        $script:validJson = @'
{
    "name": "example",
    "age": 42
}
'@
        $script:invalidJson = @'
{
    "name": "example"
}
'@
    }

    Context 'When running on PowerShell Core' -Skip:(( Get-PSVersion ).Major -lt 6) {
        It 'Should validate a valid JSON schema' {
            Test-JsonSchema -Json $script:validJson -Schema $script:schema | Should -Be $true
        }

        It 'Should throw an error for an invalid JSON schema' {
            { Test-JsonSchema -Json $script:invalidJson -Schema $script:schema } | Should -Throw
        }
    }

    Context 'When running on PowerShell Desktop' {
        BeforeAll {
            . $PSScriptRoot/Get-PSVersion.ps1
            Mock Get-PSVersion {
                [PSCustomObject]@{
                    Major = 5
                }
            }
        }

        It 'Should validate a valid JSON schema' {
            Test-JsonSchema -Json $script:validJson -Schema $script:schema | Should -Be $true
        }

        It 'Should throw an error for an invalid JSON schema' {
            { Test-JsonSchema -Json $script:invalidJson -Schema $script:schema } | Should -Throw
        }
    }
}