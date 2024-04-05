<#
.SYNOPSIS
Starts a process using the .net Process class instead of Start-Process.

.DESCRIPTION
Starts a process using the .net Process class instead of Start-Process. This allows console output to be captured
as well as non-zero exit codes at the same time.

.PARAMETER FilePath
Path to the process to start.

.PARAMETER ArgumentList
Arguments for the process.

.PARAMETER WorkingDirectory
Directory to execute the process in.

.PARAMETER PassThru
Pass the output to the pipeline.

.PARAMETER Title
Title of the progress bar that displays while the CLI is running.

.PARAMETER NoProgress
Output the command details to the information stream instead of as a progress bar.

.PARAMETER RedirectStandardError
Redirects the standard error stream to the standard output stream. Exe's that use StdErr for info: git

.EXAMPLE
Start-CliProcess -FilePath 'cmd' -ArgumentList '/c "echo hello"' -PassThru

.NOTES
Replaces Start-Process and Invoke-Process.

Notes on avoiding process deadlocks when updating the output logic:
https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standarderror#remarks
#>
function Start-CliProcess {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [Alias('LiteralPath', 'FullName')]
        [String[]]$FilePath,
        [String[]]$ArgumentList,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Directory')]
        [String]$WorkingDirectory = $PWD,
        [Switch]$PassThru,
        [Alias('Activity')]
        [String]$Title = 'Start CLI Process',
        [Switch]$NoProgress,
        [Switch]$RedirectStandardError
    )

    begin {
        $script:processes = @()
        $script:noProgress = if ($NoProgress -or $env:AGENT_JOBNAME) {
            $true
        }
        else {
            $false
        }
    }

    process {
        $procInfoArgs = if ($ArgumentList.Count -gt 1) {
            $ArgumentList | ForEach-Object -Process {
                $thisTrimmed = $_.Trim()
                if ($thisTrimmed -match ' ' -and $thisTrimmed -notmatch '"') {
                    "`"$thisTrimmed`""
                }
                else {
                    $thisTrimmed
                }
            }
        }
        elseif ($ArgumentList.Count -eq 1) {
            $ArgumentList.Trim()
        }
        foreach ($file in $FilePath) {
            $fileInfo = ( Get-Command -Name $file ).Source | Get-Item
            $processInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo'
            $processInfo.FileName = $fileInfo.FullName
            $processInfo.Arguments = $procInfoArgs
            $processInfo.WorkingDirectory = $WorkingDirectory
            $processInfo.CreateNoWindow = $true
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $process = New-Object -TypeName 'System.Diagnostics.Process'
            $process.StartInfo = $processInfo

            $progress = @{
                Activity         = $Title
                Status           = "Starting $(( Get-Command -Name $fileInfo.FullName ).Name) in $WorkingDirectory"
                CurrentOperation = "`"$($fileInfo.FullName)`" $($ArgumentList -join ' ')"
            }

            if (!$script:noProgress) {
                Write-Progress @progress
            }
            else {
                Write-ProgressToHost @progress
            }

            $null = $process.Start()
            $procState = 'Running'

            do {
                if ($procState -eq 'LastRun') {
                    $readMethod = 'ReadToEnd'
                    $procState = 'Finished'
                }
                else {
                    $readMethod = 'ReadLine'
                }

                while (!$process.StandardOutput.EndOfStream) {
                    $process.StandardOutput.$readMethod() | ForEach-Object -Process {
                        if ($PassThru) {
                            $_
                        }
                        else {
                            Write-Host -Object $_
                        }
                        if (!$script:noProgress) {
                            Write-Progress @progress
                        }
                    }
                }

                $stdErr = @()
                while (!$process.StandardError.EndOfStream) {
                    $process.StandardError.$readMethod() | ForEach-Object -Process {
                        if ($_) {
                            $stdErr += $_
                        }
                        if ($PassThru) {
                            $_
                        }
                        elseif ($RedirectStandardError) {
                            Write-Host -Object $_
                        }
                        if (!$script:noProgress) {
                            Write-Progress @progress
                        }
                    }
                }
                if ($stdErr) {
                    $stdErrString = $stdErr -join "`n"
                    if (!$RedirectStandardError) {
                        Write-Error `
                            -Message $stdErrString `
                            -Category FromStdErr `
                            -TargetObject $fileInfo.Name
                        if (!$script:noProgress) {
                            Write-Progress @progress
                        }
                    }
                }

                if ($process.HasExited -and $procState -eq 'Running') {
                    $procState = 'LastRun'
                }
            } while ($procState -ne 'Finished')
            if (!$script:noProgress) {
                Write-Progress @progress -Completed
            }

            if (
                ($process.ExitCode -ne 0) -and
                ($ErrorActionPreference -ne 'SilentlyContinue') -and
                ($ErrorActionPreference -ne 'Ignore')
            ) {
                throw $process.ExitCode
            }
            $script:processes += $process.Id
        }
    }

    end {
        if ($script:processes) {
            Stop-Process -Id $script:processes -Force -PassThru -ErrorAction SilentlyContinue | Wait-Process
        }
    }
}
