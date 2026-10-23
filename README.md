# JBUtils

A PowerShell module with functions for common, low-level tasks.

## Setup

```powershell
Install-Module -Name JBUtils
```

JBUtils supports Windows PowerShell 5.1 and PowerShell Core.

## CycloneDX documents

`Import-CycloneDxSbom` reads a CycloneDX 1.6 JSON document after validation with an
installed [CycloneDX CLI](https://github.com/CycloneDX/cyclonedx-cli). Supply its executable
path when it is not available as `cyclonedx-cli` on PATH:

```powershell
$document = Import-CycloneDxSbom -Path './out/package.cdx.json' -ValidatorPath './tools/cyclonedx.exe'
$document.components | Select-Object name, version, purl
```

The command validates a temporary snapshot, returns the parsed document, and removes the
snapshot on success or failure. Invalid JSON, unsupported formats, missing tools, and
schema errors terminate. It does not install tools or change the source file. It accepts
the suppliers, package ecosystems, licenses, and composition states allowed by the schema.
Callers must separately verify artifact hashes, inventory coverage, provenance, and any
submission policy. Schema validation alone does not establish those properties.

`Export-CycloneDxSbom` validates serialized JSON before writing it. The destination's
parent directory must exist. Supply `-Force` to replace an existing file, or `-WhatIf`
to preview the write without invoking the validator or creating files:

```powershell
$json = $document | ConvertTo-Json -Depth 100
Export-CycloneDxSbom -Json $json -Path './out/package.cdx.json' -ValidatorPath './tools/cyclonedx.exe' -Force
```

The command preserves the JSON text and returns a `FileInfo`. Callers control serialization
depth and apply their own policy checks. The writer uses a temporary file in the destination
directory before filesystem replacement. Validation or staging failures leave an existing
destination unchanged. Temporary files are removed on success and failure.

## Development

Follow the [PowerShell Best Practices and Style Guide](https://poshcode.gitbooks.io/powershell-practice-and-style/)
and these repository conventions:

- Use approved verbs and add comment-based help to every function.
- Keep each function in a same-named `.ps1` file.
- Put exported functions in `src/Public` and implementation details in `src/Private`.
- Do not use `Export-ModuleMember` in source files. ModuleBuilder derives exports from `src/Public`.
- Keep tests under the top-level `tests` directory, mirroring the source layout.
- Treat `src/JBUtils.psd1` as the authored module manifest. The generated `.psm1` and release manifest belong
  under `out`.
- Preserve Windows PowerShell 5.1 compatibility unless a major release explicitly changes the requirement.

Building requires PowerShell 7.4 or newer, PSModuleUtils 5.x, and Pester 6.2 or newer within 6.x.
Runtime support remains Windows PowerShell 5.1 and PowerShell Core. Start a fresh build process
after using Pester 5.

```powershell
Install-Module -Name PSModuleUtils -MinimumVersion 5.0.0 -MaximumVersion 5.999.999 -Scope CurrentUser
./build.ps1
```

The build analyzes the source, creates the versioned module under `out/JBUtils`, runs the full Pester suite,
and verifies that the built module can be packaged for publication. GitHub Actions excludes
`HostIntegration` tests because its runner has no interactive Windows desktop. The default local
build still selects the full suite. Run the full suite only on a
disposable Windows host: `HostIntegration` tests install software, modify persistent environment
settings, capture the desktop, stop processes, or require an interactive Windows console. To build and run the remaining tests locally:

```powershell
Import-Module -FullyQualifiedName @{ ModuleName = 'PSModuleUtils'; RequiredVersion = '5.0.0' }
Build-PSModule
Test-PSModule -Name JBUtils -ExcludeTag HostIntegration
```

```text
JBUtils/
|-- src/
|   |-- JBUtils.psd1
|   |-- Private/
|   `-- Public/
|-- tests/
|   |-- JBUtils.Module.Tests.ps1
|   |-- Private/
|   `-- Public/
|-- build.ps1
`-- publish.ps1
```
