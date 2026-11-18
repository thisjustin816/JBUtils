<#
.SYNOPSIS
Runs a native command with inherited, overridden or complete child environments and reports nonzero exits.

.DESCRIPTION
Runs a native executable with the call operator so it inherits the console: output streams straight
through, and interactive rendering such as docker build progress or maven colors is preserved.
A nonzero exit code becomes a terminating error carrying the supplied message.

With Environment, a separate PowerShell job applies overrides only in its child process. Output is
streamed back through the pipeline, including native stderr. This mode does not provide an interactive
console. The caller's environment remains unchanged, including during concurrent invocations.

ExactEnvironment requires PowerShell 7 and replaces the complete child environment. It streams text
chunks and can send private startup input through stdin. Pipeline stop and cancellation dispose
the owned process tree. Other invocation modes retain their inherited-console or job behavior.

Use Start-CliProcess for progress reporting or separate stderr handling.

.PARAMETER FilePath
Native executable or script to invoke. PATH-resolved names are accepted.

.PARAMETER ArgumentList
Arguments passed literally to the native command, including wildcard characters.

.PARAMETER FailureMessage
Message included in the terminating error. The exit code is appended. Defaults to a generic
message naming the command.

.PARAMETER Environment
Optional child-process environment overrides. Values must be strings or null; null removes a variable
from the child environment. Unspecified variables are inherited. Overrides are sent through the job
input channel, never written to a file or included in the native command arguments.

.PARAMETER WorkingDirectory
Optional directory to run the command in. The caller's location is restored afterward.

.PARAMETER ExactEnvironment
Complete child environment, requiring PowerShell 7. Unspecified and null-valued variables are absent.
Streams stdout and stderr as text chunks without a terminal or a runtime deadline. Application output
is public logging; this mode does not provide the private captured response of Invoke-NativeProtocol.
Cannot be combined with Environment.

.PARAMETER InputText
Private startup input for exact mode. Strict UTF-8 is sent once through stdin, which is then closed.
Input is never added to arguments, files or reported failures.

.PARAMETER MaxInputBytes
Maximum UTF-8 input size in exact mode, checked before starting the child. Defaults to 8 MiB.

.PARAMETER CancellationToken
Optional cancellation for exact mode. Cancellation and pipeline stop terminate the child and attached
process tree. Detached or reparented descendants require external process containment.

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
    [CmdletBinding(DefaultParameterSetName = 'Inherited')]
    param(
        [Parameter(Mandatory)]
        [String]$FilePath,

        [String[]]$ArgumentList = @(),

        [String]$FailureMessage = "'$FilePath' failed.",

        [String]$WorkingDirectory,

        [Parameter(ParameterSetName = 'Inherited')]
        [ValidateNotNull()]
        [System.Collections.IDictionary]$Environment,

        [Parameter(Mandatory, ParameterSetName = 'Exact')]
        [AllowEmptyCollection()]
        [ValidateNotNull()]
        [System.Collections.IDictionary]$ExactEnvironment,

        [Parameter(ParameterSetName = 'Exact')]
        [AllowEmptyString()]
        [String]$InputText = '',

        [Parameter(ParameterSetName = 'Exact')]
        [ValidateRange(0, 2147483647)]
        [Int32]$MaxInputBytes = 8388608,

        [Parameter(ParameterSetName = 'Exact')]
        [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None
    )

    if ($PSCmdlet.ParameterSetName -eq 'Exact') {
        if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Exact native environment requires PowerShell 7.' }
        try {
            $command = Get-Command -Name $FilePath -CommandType Application -ErrorAction Stop |
                Select-Object -First 1
            $directory = if ($WorkingDirectory) { $WorkingDirectory } else { (Get-Location).Path }
            $directory = Get-Item -LiteralPath $directory -Force -ErrorAction Stop
            if ($directory -isnot [IO.DirectoryInfo]) { throw 'StartFailed' }
            $start = [Diagnostics.ProcessStartInfo]::new()
            $start.FileName = $command.Source
            $start.WorkingDirectory = $directory.FullName
            foreach ($argument in $ArgumentList) { $start.ArgumentList.Add($argument) }
            $start.Environment.Clear()
            foreach ($entry in $ExactEnvironment.GetEnumerator()) {
                if ($entry.Key -isnot [String] -or $entry.Key -notmatch '\A[^=\x00]+\z' -or
                    ($null -ne $entry.Value -and $entry.Value -isnot [String]) -or
                    ($entry.Value -is [String] -and $entry.Value.Contains([Char]0))) {
                    throw 'InvalidEnvironment'
                }
                if ($null -ne $entry.Value) { $start.Environment.Add($entry.Key, $entry.Value) }
            }
            Invoke-ProcessExchange `
                -StartInfo $start `
                -InputText $InputText `
                -MaxInputBytes $MaxInputBytes `
                -Streaming `
                -CancellationToken $CancellationToken
        }
        catch {
            $failure = $_
            $exception = $failure.Exception
            while ($exception.InnerException) { $exception = $exception.InnerException }
            $category = 'StartFailed'
            if ($exception.Message -cmatch '\AExitCode:(-?[0-9]+)\z') {
                throw "$FailureMessage Exit code: $($Matches[1])"
            }
            if (@('InputLimitExceeded', 'InvalidInputEncoding', 'InvalidEnvironment', 'Cancelled',
                    'WriteFailed', 'ReadFailed', 'StartFailed') -ccontains $exception.Message) {
                $category = $exception.Message
            }
            throw "$FailureMessage Native command failed: $category."
        }
        finally { $InputText = $null }
        return
    }

    # Quoted argument expressions prevent Unix wildcard expansion without interpolating argument data into code.
    $argumentExpressions = for ($index = 0; $index -lt $ArgumentList.Count; $index++) {
        ('"$($NativeArguments[' + $index + '])"')
    }
    $invocationText = (
        'param($NativeExecutable, $NativeArguments) & $NativeExecutable ' +
        ($argumentExpressions -join ' ')
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
            param($Executable, $Arguments, $Directory, $Overrides, $Message, $InvocationText)
            foreach ($entry in $Overrides.GetEnumerator()) {
                if ($null -eq $entry.Value) {
                    [Environment]::SetEnvironmentVariable($entry.Key, [NullString]::Value, 'Process')
                }
                else {
                    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
                }
            }
            Set-Location -LiteralPath $Directory -ErrorAction Stop
            & ([ScriptBlock]::Create($InvocationText)) $Executable $Arguments 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "$Message Exit code: $LASTEXITCODE"
            }
        } -ArgumentList $command.Source, $ArgumentList, $directory, $Environment, $FailureMessage, $invocationText
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
        & ([ScriptBlock]::Create($invocationText)) $FilePath $ArgumentList
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
