<#
.SYNOPSIS
Stops a process and all child processes that it spawned.

.DESCRIPTION
Stops a process and all child processes that it spawned.

.PARAMETER ProcessId
ID of the process to stop.

.EXAMPLE
Get-Process cmd | Stop-ProcessTree

.LINK
https://stackoverflow.com/a/55942155/14628263

.NOTES
N/A
#>
function Stop-ProcessTree {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [Int[]]$ProcessId
    )

    begin {
        $script:CurrentProcess = Get-CimInstance -ClassName Win32_Process |
            Where-Object -FilterScript { $_.ProcessId -eq $PID }
    }

    process {
        foreach ($id in $ProcessId) {
            Get-CimInstance -ClassName Win32_Process |
                Where-Object -FilterScript {
                    $_.ParentProcessId -eq $id -and
                    (
                        $script:CurrentProcess.ProcessId,
                        $script:CurrentProcess.ParentProcessId
                    ) -notcontains $_.ProcessId
                } |
                ForEach-Object -Process { Stop-ProcessTree -ProcessId $_.ProcessId }
            $processToStop = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
            if ($processToStop) {
                <# Use for debugging unexpected kill behavior
                $processToStop |
                    Format-Table -HideTableHeaders |
                    Out-File -FilePath "$PSScriptRoot/Stop-ProcessTree.log" -Append
                #>
                $processToStop | Stop-Process -Force -PassThru | Wait-Process
            }
        }
    }
}
