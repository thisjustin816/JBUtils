<#
.SYNOPSIS
Validates a JSON object against a JSON schema.
.DESCRIPTION
This function takes a JSON object and a JSON schema as input and validates the JSON object against the schema. If the JSON object is valid, it returns true. Otherwise, it throws an error with the validation errors.
.PARAMETER Json
(Required) The JSON object to validate.
.PARAMETER Schema
(Required) The JSON schema to validate against.
.EXAMPLE
$Json = '{"name": "example"}'
$Schema = '{"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}'
Test-JsonSchema -Json $Json -Schema $Schema
.NOTES
Requires the Newtonsoft.Json and Newtonsoft.Json.Schema .NET libraries.
.LINK
https://stackoverflow.com/q/49383121
#>
function Test-JsonSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Json,
        [Parameter(Mandatory = $true)]
        [String]$Schema
    )
    begin {
        $script:pwsh = ( Get-PSVersion ).Major -ge 6
        if (-not $script:pwsh) {
            . "$PSScriptRoot/../private/Import-JsonAssembly.ps1"
            Import-JsonAssembly
        }
    }

    process {
        if ($script:pwsh) {
            Test-Json -Json $Json -Schema $Schema -ErrorAction Stop
        }
        else {
            $jSchema = [Newtonsoft.Json.Schema.JSchema]::Parse($Schema)
            $jObject = [Newtonsoft.Json.Linq.JObject]::Parse($Json)
            $result = @( [Validator]::Validate($jObject, $jSchema) )
            if($result) {
                foreach ($errorMsg in $result) {
                    Write-Error $errorMsg
                }
                throw 'JSON validation failed.'
            }
            else {
                $true
            }
        }
    }
}