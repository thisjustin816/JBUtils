<#
.SYNOPSIS
Returns boolean determining if prompt was run non-interactively.

.DESCRIPTION
First, we check `[Environment]::UserInteractive` to determine if the shell is running
interactively. An example of not running interactively would be if the shell is running as a service.
If we are running interactively, we check the Command Line Arguments to see if the `-NonInteractive`
switch was used; or an abbreviation of the switch.

.LINK
https://github.com/Vertigion/Test-IsNonInteractiveShell
#>
function Test-IsNonInteractiveShell {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param ()

    if ([Environment]::UserInteractive) {
        $commandLineArgs = [Environment]::GetCommandLineArgs()
        $isNonInteractive = $commandLineArgs -contains '-NonInteractive'
        $isVsCode = foreach ($arg in $commandLineArgs) {
            if ($arg -match "-HostProfileId\ 'Microsoft\.VSCode'") {
                $true
            }
        }
    }

    if (
        $env:AGENT_JOBNAME -or
        (
            $isNonInteractive -and
            !$isVsCode
        )
    ) {
        $true
    }
    else {
        $false
    }
}