<#
.SYNOPSIS
Reads a CycloneDX 1.6 JSON document after schema validation.

.DESCRIPTION
Validates a temporary snapshot with the installed official CycloneDX CLI and returns
the parsed document. The CLI must succeed with --fail-on-errors. Missing tools, invalid
JSON, unsupported formats, and schema failures terminate. The source file is unchanged.

Schema validation does not establish inventory completeness, artifact integrity,
license accuracy, or compliance with a submission policy. Callers apply those checks.

.PARAMETER Path
Literal filesystem path to the JSON document. PowerShell provider paths are accepted.

.PARAMETER ValidatorPath
Installed CycloneDX CLI executable path or application name on PATH. No tool is installed.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
$document = Import-CycloneDxSbom -Path './out/package.cdx.json' -ValidatorPath 'cyclonedx-cli'

.LINK
https://github.com/CycloneDX/cyclonedx-cli#validate-command
#>
function Import-CycloneDxSbom {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$ValidatorPath = 'cyclonedx-cli'
    )

    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($file.PSProvider.Name -ne 'FileSystem' -or $file.PSIsContainer) {
        throw 'The SBOM path must identify a filesystem file.'
    }

    $json = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
    if (-not $json -or -not $json.TrimStart().StartsWith('{')) {
        throw 'The SBOM must be a JSON object.'
    }
    $document = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    $format = $document.PSObject.Properties['bomFormat']
    $version = $document.PSObject.Properties['specVersion']
    if (-not $format -or -not $version -or $format.Value -cne 'CycloneDX' -or $version.Value -cne '1.6') {
        throw 'Only CycloneDX 1.6 JSON documents are supported.'
    }

    $validator = Get-Command -Name $ValidatorPath -CommandType Application -ErrorAction Stop |
        Select-Object -First 1

    $snapshot = New-TemporaryFile -ErrorAction Stop
    try {
        Set-Content -LiteralPath $snapshot.FullName -Value $json -NoNewline -Encoding UTF8 -ErrorAction Stop
        $arguments = @(
            'validate'
            '--input-file', $snapshot.FullName
            '--input-format', 'json'
            '--input-version', 'v1_6'
            '--fail-on-errors'
        )
        Invoke-NativeCommand `
            -FilePath $validator.Source `
            -ArgumentList $arguments `
            -FailureMessage 'CycloneDX schema validation failed.' |
            ForEach-Object { Write-Verbose -Message ([String]$_) }

        $document
    }
    finally {
        Remove-Item -LiteralPath $snapshot.FullName -Force -ErrorAction SilentlyContinue
    }
}
