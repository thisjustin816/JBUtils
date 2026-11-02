<#
.SYNOPSIS
Runs a native command with optional child-only environment overrides and reports nonzero exits.

.DESCRIPTION
Runs a native executable with the call operator so it inherits the console: output streams straight
through, and interactive rendering such as docker build progress or maven colors is preserved.
A nonzero exit code becomes a terminating error carrying the supplied message.

With Environment, a separate PowerShell job applies overrides only in its child process. Output is
streamed back through the pipeline, including native stderr. This mode does not provide an interactive
console. The caller's environment remains unchanged, including during concurrent invocations.

Use Start-CliProcess for progress reporting or separate stderr handling.

.PARAMETER FilePath
Native executable or script to invoke. PATH-resolved names are accepted.

.PARAMETER ArgumentList
Arguments passed to the native command.

.PARAMETER FailureMessage
Message included in the terminating error. The exit code is appended. Defaults to a generic
message naming the command.

.PARAMETER Environment
Optional child-process environment overrides. Values must be strings or null; null removes a variable
from the child environment. Unspecified variables are inherited. Overrides are sent through the job
input channel, never written to a file or included in the native command arguments.

.PARAMETER WorkingDirectory
Optional directory to run the command in. The caller's location is restored afterward.

.EXAMPLE
Invoke-NativeCommand -FilePath 'docker' -ArgumentList @('push', $image) -FailureMessage 'Push failed.'

.EXAMPLE
Invoke-NativeCommand -FilePath $maven -ArgumentList $args -FailureMessage 'Build failed.' -WorkingDirectory $dir

.NOTES
N/A
#>
function Invoke-NativeCommand {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseUsingScopeModifierInNewRunspaces', '',
        Justification = 'Job variables are declared as script-block parameters or locals.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$FilePath,

        [String[]]$ArgumentList = @(),

        [String]$FailureMessage = "'$FilePath' failed.",

        [String]$WorkingDirectory,

        [ValidateNotNull()]
        [System.Collections.IDictionary]$Environment
    )

    if ($PSBoundParameters.ContainsKey('Environment')) {
        foreach ($entry in $Environment.GetEnumerator()) {
            if ($entry.Key -isnot [String] -or $entry.Key -notmatch '\A[^=\x00]+\z' -or
                ($null -ne $entry.Value -and $entry.Value -isnot [String]) -or
                ($entry.Value -is [String] -and $entry.Value.Contains([Char]0))) {
                throw 'Environment overrides require valid variable names and string or null values.'
            }
        }
        $command = Get-Command -Name $FilePath -CommandType Application, ExternalScript -ErrorAction Stop |
            Select-Object -First 1
        $directory = if ($WorkingDirectory) { $WorkingDirectory } else { (Get-Location).Path }
        $directory = (Resolve-Path -LiteralPath $directory -ErrorAction Stop).ProviderPath
        $job = Start-Job -ScriptBlock {
            param($Executable, $Arguments, $Directory, $Overrides, $Message)
            foreach ($entry in $Overrides.GetEnumerator()) {
                [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
            }
            Set-Location -LiteralPath $Directory -ErrorAction Stop
            & $Executable @Arguments 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "$Message Exit code: $LASTEXITCODE"
            }
        } -ArgumentList $command.Source, $ArgumentList, $directory, $Environment, $FailureMessage
        try {
            Receive-Job -Job $job -Wait -ErrorAction Stop
        }
        finally {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        return
    }
    if ($WorkingDirectory) {
        Push-Location -LiteralPath $WorkingDirectory
    }

    try {
        & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "$FailureMessage Exit code: $LASTEXITCODE"
        }
    }
    finally {
        if ($WorkingDirectory) {
            Pop-Location
        }
    }
}
