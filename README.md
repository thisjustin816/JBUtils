# JBUtils

A PowerShell module with functions for common, low-level tasks.

## Setup

```powershell
Install-Module -Name JBUtils
```

JBUtils supports Windows PowerShell 5.1 and PowerShell Core.

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

Install PSModuleUtils 2.0.0 or later, then run the build from the repository root:

```powershell
Install-Module -Name PSModuleUtils -MinimumVersion 2.0.0 -Scope CurrentUser
./build.ps1
```

The build analyzes the source, creates the versioned module under `out/JBUtils`, runs the full Pester suite,
and verifies that the built module can be packaged for publication.

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
