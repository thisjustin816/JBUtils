<#
.SYNOPSIS
Writes an object to a JSON file.

.DESCRIPTION
Serializes the input object to JSON (depth 100, to cover deeply nested config/manifest objects) and
writes it to the given path.

.PARAMETER InputObject
The object to serialize. Accepts pipeline input.

.PARAMETER Path
The file path to write to.

.EXAMPLE
$manifest | Set-JsonFile -Path './release-manifest.json'

.NOTES
N/A
#>
function Set-JsonFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Object]$InputObject,

        [Parameter(Mandatory)]
        [String]$Path
    )

    process {
        if ($PSCmdlet.ShouldProcess($Path, 'Write JSON file')) {
            $InputObject | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8
        }
    }
}
