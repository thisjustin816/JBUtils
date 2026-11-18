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

## OS credentials

`Get-OsCredential`, `Set-OsCredential` and `Remove-OsCredential` use Git Credential Manager with
Windows Credential Manager, macOS Keychain or Linux Secret Service. Install Git Credential Manager
and unlock the user store before using these commands. Linux needs a desktop Secret Service session.
An unavailable store raises an error; these commands never fall back to plaintext files.

Use a stable name and application namespace to keep entries separate from Git credentials. The
commands do not change Git configuration. Passwords travel through redirected stdin, not process
arguments, and reads return a `PSCredential`. Reading a missing entry raises an error without starting
an authentication flow. The plaintext protocol exists transiently in process memory.

```powershell
$credential = Get-Credential -UserName 'developer'
Set-OsCredential -Name 'sample-token' -Namespace 'sample-app' -Credential $credential
$credential = Get-OsCredential -Name 'sample-token' -Namespace 'sample-app' -UserName 'developer'
Remove-OsCredential -Name 'sample-token' -Namespace 'sample-app' -UserName 'developer'
```

## Native commands with child-only environment values

Invoke-NativeCommand streams a command's output and throws on a nonzero exit code.
ArgumentList preserves literal wildcard characters, spaces, quotes and empty arguments.
Supply -Environment when a command needs temporary environment values:

~~~powershell
Invoke-NativeCommand -FilePath $executable -ArgumentList @('--version') -Environment @{
    TOOL_SESSION = 'temporary-value'
    UNUSED_SETTING = $null
}
~~~

This mode uses a separate PowerShell job and sends overrides through its input channel.
A null value removes the variable in the child. Other variables are inherited. The parent
environment stays unchanged, including when commands run concurrently. Output and native stderr
return through the pipeline; this mode cannot provide an interactive console. The caller
must redact sensitive output before displaying or storing it. Overrides are never placed in
native arguments or temporary files.

For a complete environment on PowerShell 7, use `-ExactEnvironment`:

~~~powershell
Invoke-NativeCommand -FilePath $executable -ArgumentList @('--run') -ExactEnvironment @{
    PATH = $env:PATH
    TOOL_SESSION = 'temporary-value'
} -InputText $startupRequest
~~~

Only supplied variables reach the executable. Null values are absent; empty strings remain present.
Private startup input is strict UTF-8, limited to 8 MiB by default, and sent once through stdin.
Output and stderr stream as text chunks, including output without newlines. This mode has no total
runtime deadline or cumulative output limit; a bounded queue applies backpressure. It does not
provide an interactive console or a private protocol response. Redact sensitive application logging
before displaying or storing it, accounting for values split across chunks. The input and environment
are never included in reported failures.
Cancellation and pipeline stop terminate the process and its attached descendants; detached or
reparented processes require external containment. `Environment` and `ExactEnvironment` cannot be combined.

Without either environment parameter, the inherited-console invocation remains in use.

## Private native protocol exchange

`Invoke-NativeProtocol` requires PowerShell 7 and returns captured UTF-8 stdout to its caller.
Supply a complete `Environment` dictionary and private `InputText`; parent variables are not inherited.
Capture and validate the returned string before displaying or storing anything. The helper does not
interpret or sanitize protocol records.

The exchange limits stdin to 8 MiB, stdout to 16 KiB, stderr to 64 KiB and communication to 30 seconds
by default. Parameters can set smaller limits. Unexpected stderr, invalid UTF-8, overflow, cancellation,
failed startup and nonzero exit produce fixed failure categories without native data. Timeout and
cancellation terminate the child and its attached process tree. Detached descendants or descendants that
outlive their parent are outside this cleanup guarantee. Use a non-detaching executable; this helper
does not provide process containment. Input travels through stdin, never temporary files or shell arguments.
Existing credential-store helpers preserve their inherited environment and accepted output behavior.

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
