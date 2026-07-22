<#
.SYNOPSIS
Prepend a value to the PATH environment variable in Azure Pipelines that can be used in subsequent tasks.

.DESCRIPTION
Prepend a value to the PATH environment variable in Azure Pipelines that can be used in subsequent tasks. It will
only print the console syntax if running on a pipeline agent.

.PARAMETER Path
Path to prepend.

.EXAMPLE
Add-AzPipelinesPathEntry -Path C:/path/to/prepend

.NOTES
N/A
#>
function Add-AzPipelinesPathEntry {
    [CmdletBinding()]
    param (
        [String[]]$Path
    )

    if ($env:AGENT_JOBNAME) {
        $processedPaths = @(
            foreach ($entry in $Path) {
                $entry.Split([System.IO.Path]::PathSeparator) |
                    Where-Object -FilterScript { $_ }
            }
        )

        $resolvedPaths = @()
        $resolvedPaths += foreach ($entry in $processedPaths) {
            try {
                ( Resolve-Path -Path $entry -ErrorAction Stop ).Path
            }
            catch {
                Write-Warning -Message $_.Exception.Message
                $entry
            }
        }

        $joinedPaths = $resolvedPaths -join [System.IO.Path]::PathSeparator

        Write-Host -Object "##vso[task.prependpath]$joinedPaths"
    }
}