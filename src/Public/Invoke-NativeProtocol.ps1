<#
.SYNOPSIS
Exchanges private UTF-8 input with a bounded, redirected native process.

.DESCRIPTION
Requires PowerShell 7. Replaces the complete child environment before starting the executable.
Returns captured stdout only. The caller must capture and validate that private result before emitting it.
Native stderr, input and exception details are never included in reported failures.

.PARAMETER Environment
The complete child environment. No parent variables are inherited.

.PARAMETER InputText
Private UTF-8 input sent through stdin, with its byte limit checked before process creation.

.PARAMETER CancellationToken
An optional caller cancellation token. Cancellation terminates the child and its attached process tree.
Detached descendants and descendants that outlive their parent require external process containment.

.OUTPUTS
System.String
#>
function Invoke-NativeProtocol {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)][String]$FilePath,
        [String[]]$ArgumentList = @(),
        [Parameter(Mandatory)][String]$WorkingDirectory,
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.IDictionary]$Environment,
        [Parameter(Mandatory)][AllowEmptyString()][String]$InputText,
        [ValidateRange(1, 2147483647)][Int32]$TimeoutMilliseconds = 30000,
        [ValidateRange(0, 2147483647)][Int32]$MaxInputBytes = 8388608,
        [ValidateRange(0, 2147483647)][Int32]$MaxOutputBytes = 16384,
        [ValidateRange(0, 2147483647)][Int32]$MaxErrorBytes = 65536,
        [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None
    )

    if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Native protocol requires PowerShell 7.' }
    $category = 'StartFailed'
    try {
        $executable = Get-Item -LiteralPath $FilePath -ErrorAction Ignore
        $directory = Get-Item -LiteralPath $WorkingDirectory -ErrorAction Ignore
        if ($executable -isnot [IO.FileInfo] -or $directory -isnot [IO.DirectoryInfo]) {
            throw 'StartFailed'
        }
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $executable.FullName
        $start.WorkingDirectory = $directory.FullName
        foreach ($argument in $ArgumentList) { $start.ArgumentList.Add($argument) }
        $start.Environment.Clear()
        foreach ($entry in $Environment.GetEnumerator()) {
            $start.Environment.Add([String]$entry.Key, [String]$entry.Value)
        }
        $parameters = @{
            StartInfo           = $start
            InputText           = $InputText
            TimeoutMilliseconds = $TimeoutMilliseconds
            MaxInputBytes       = $MaxInputBytes
            MaxOutputBytes      = $MaxOutputBytes
            MaxErrorBytes       = $MaxErrorBytes
            StrictProtocol      = $true
            CancellationToken   = $CancellationToken
        }
        Invoke-ProcessExchange @parameters
    }
    catch {
        $failure = $_
        $exception = $failure.Exception
        while ($exception.InnerException) { $exception = $exception.InnerException }
        $known = @(
            'InputLimitExceeded', 'OutputLimitExceeded', 'ErrorLimitExceeded', 'UnexpectedErrorOutput'
            'TimedOut', 'Cancelled', 'StartFailed', 'ExitFailed', 'InvalidOutputEncoding'
            'WriteFailed', 'ReadFailed', 'ExchangeFailed', 'InvalidInputEncoding'
        )
        if ($known -ccontains $exception.Message) { $category = $exception.Message }
        throw "Native protocol failed: $category."
    }
    finally { $InputText = $null }
}
