
<#
.SYNOPSIS
Use in place of Write-Progress to output the content to the console instead of a progress bar.
#>
function Write-ProgressToHost {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]$Activity,
        [String]$Status,
        [Int32]$Id,
        [Int32]$PercentComplete,
        [Int32]$SecondsRemaining,
        [String]$CurrentOperation,
        [Int32]$ParentId,
        [Switch]$Completed,
        [Int32]$SourceId
    )

    $paramOutputOrder = @(
        'Activity',
        'Status',
        'PercentComplete',
        'CurrentOperation',
        'SecondsRemaining',
        'Completed'
    )

    $params = $paramOutputOrder |
        Where-Object -FilterScript { $PSBoundParameters.Keys -contains $_ }

    $paramValues = $params | ForEach-Object -Process {
        switch ($_) {
            'PercentComplete' {
                $percent = '['
                $progressByTen = [Math]::Floor($PercentComplete / 10)
                for ($i = 0; $i -lt $progressByTen; $i++) {
                    $percent += '#'
                }
                for ($i = 0; $i -lt 10 - $progressByTen; $i++) {
                    $percent += ' '
                }
                $percent += ']'
                $percent
            }
            'SecondsRemaining' { "-$($SecondsRemaining)s" }
            'Completed' { 'Completed' }
            Default { $PSBoundParameters[$_] }
        }
    }

    $message = ''
    if ($env:AGENT_JOBNAME) {
        $message += '##[info] '
    }
    $message += ($paramValues -join ' | ')
    if ($ProgressPreference -eq 'Continue') {
        Write-Host -Object $message -ForegroundColor DarkGray
    }
    else {
        Write-Verbose -Message $message
    }
}
