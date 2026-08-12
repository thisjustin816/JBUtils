<#
.SYNOPSIS
Invokes a native command with an inherited console and throws when it exits nonzero.

.DESCRIPTION
Runs a native executable with the call operator so it inherits the console: output streams straight
through, and interactive rendering such as docker build progress or maven colors is preserved.
A nonzero exit code becomes a terminating error carrying the supplied message.

Use Start-CliProcess instead when output must be captured or stderr should surface as error
records; use this when the command's own console output is the user experience and only the exit
code decides success.

.PARAMETER FilePath
Native executable or script to invoke. PATH-resolved names are accepted.

.PARAMETER ArgumentList
Arguments passed to the native command.

.PARAMETER FailureMessage
Message included in the terminating error. The exit code is appended. Defaults to a generic
message naming the command.

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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$FilePath,

        [String[]]$ArgumentList = @(),

        [String]$FailureMessage = "'$FilePath' failed.",

        [String]$WorkingDirectory
    )

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
