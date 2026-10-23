<#
.SYNOPSIS
Writes a CycloneDX 1.6 JSON document after schema validation.

.DESCRIPTION
Validates the supplied JSON with Import-CycloneDxSbom before writing the destination.
Writes through a temporary file in the destination directory and removes temporary
files on success or failure. Existing files require Force. Validation and staging
failures leave an existing destination unchanged.

The caller supplies serialized JSON and owns inventory, provenance, and policy checks.
The command preserves the JSON text and does not install tools or create directories.

.PARAMETER Json
Serialized CycloneDX 1.6 JSON document. Serialization depth is controlled by the caller.

.PARAMETER Path
Literal output file path with an existing filesystem parent. Provider paths are accepted.

.PARAMETER ValidatorPath
Installed CycloneDX CLI executable path or application name on PATH.

.PARAMETER Force
Replaces an existing destination after successful validation. WhatIf still applies.

.OUTPUTS
System.IO.FileInfo

.EXAMPLE
$json = $document | ConvertTo-Json -Depth 100
Export-CycloneDxSbom -Json $json -Path './out/package.cdx.json' -ValidatorPath './tools/cyclonedx.exe'
#>
function Export-CycloneDxSbom {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Json,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [ValidateNotNullOrEmpty()]
        [String]$ValidatorPath = 'cyclonedx-cli',

        [Switch]$Force
    )

    $provider = $null
    $drive = $null
    $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $Path, [Ref]$provider, [Ref]$drive
    )
    if ($provider.Name -ne 'FileSystem') {
        throw 'The SBOM destination must be a filesystem file.'
    }
    $parent = Get-Item -LiteralPath (Split-Path -Path $destination -Parent) -ErrorAction Stop
    if (-not $parent.PSIsContainer) {
        throw 'The SBOM destination parent must be a directory.'
    }
    if (Test-Path -LiteralPath $destination -PathType Container) {
        throw 'The SBOM destination must be a filesystem file.'
    }
    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        throw 'The SBOM destination already exists. Use Force to replace it.'
    }
    if (-not $PSCmdlet.ShouldProcess($destination, 'Write validated CycloneDX document')) {
        return
    }

    $snapshot = New-TemporaryFile -ErrorAction Stop
    $stagedFile = $null
    try {
        Set-Content -LiteralPath $snapshot.FullName -Value $Json -NoNewline -Encoding UTF8 -ErrorAction Stop
        $null = Import-CycloneDxSbom -Path $snapshot.FullName -ValidatorPath $ValidatorPath

        $stagedPath = Join-Path $parent.FullName ('.sbom-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        $stagedFile = New-Item -Path $stagedPath -ItemType File -ErrorAction Stop
        Set-Content -LiteralPath $stagedFile.FullName -Value $Json -NoNewline -Encoding UTF8 -ErrorAction Stop

        # Same-directory filesystem replacement avoids truncating the destination before the write succeeds.
        # Both paths are absolute filesystem paths resolved through PowerShell's provider APIs.
        if ($Force -and (Test-Path -LiteralPath $destination)) {
            [System.IO.File]::Replace($stagedFile.FullName, $destination, [NullString]::Value)
        }
        else {
            [System.IO.File]::Move($stagedFile.FullName, $destination)
        }
        Get-Item -LiteralPath $destination -ErrorAction Stop
    }
    finally {
        Remove-Item -LiteralPath $snapshot.FullName -Force -ErrorAction SilentlyContinue
        if ($stagedFile) {
            Remove-Item -LiteralPath $stagedFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}
