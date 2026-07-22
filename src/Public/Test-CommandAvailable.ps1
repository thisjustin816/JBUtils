<#
.SYNOPSIS
Verifies a required CLI command is available on PATH.

.DESCRIPTION
Throws a clear, actionable error when the command cannot be found, rather than letting a later native
command invocation fail with an unhelpful "command not found" error.

.PARAMETER CommandName
The command to check for.

.PARAMETER ErrorMessage
A custom error message. Defaults to a generic "not on PATH" message naming the command.

.EXAMPLE
Test-CommandAvailable -CommandName 'docker'

.NOTES
N/A
#>
function Test-CommandAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$CommandName,

        [String]$ErrorMessage = (
            "The '$CommandName' command is not on PATH. " +
            'Install the CLI or add its bin directory to PATH.'
        )
    )

    if (-not (Get-Command -Name $CommandName -ErrorAction SilentlyContinue)) {
        throw $ErrorMessage
    }
}
