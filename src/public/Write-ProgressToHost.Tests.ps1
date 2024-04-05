[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
[CmdletBinding()]
param ()

Describe 'Integration Tests' {
    BeforeAll {
        . $PSScriptRoot/Write-ProgressToHost.ps1
    }

    It 'should use the same parameters as Write-Progress' {
        $max = 10
        $digits = $max.ToString().Length
        for ($i = 0; $i -le $max; $i++) {
            $script:progress = @{
                Activity         = "Counting to $max"
                Status           = "$("{0:d$digits}" -f $i)/$max"
                Id               = 1
                PercentComplete  = ($i / $max) * 100
                SecondsRemaining = [Math]::Floor(($max - $i) / 4)
                CurrentOperation = "Count: $("{0:d$digits}" -f $i)"
                ParentId         = 0
                SourceId         = -1
            }

            Write-Progress @script:progress
            { Write-ProgressToHost @script:progress } | Should -Not -Throw
            Start-Sleep -Milliseconds 250
        }

        Write-Progress @script:progress -Completed
        { Write-ProgressToHost @script:progress -Completed } | Should -Not -Throw
    }

    It 'should prefix with ##[info] on a build agent' {
        $ProgressPreference = 'Continue'
        $prevJobName = $env:AGENT_JOBNAME
        $env:AGENT_JOBNAME = $null
        Write-ProgressToHost 'Test' 6>&1 | Should -Not -Match "$([Regex]::Escape('##[info]'))"
        $env:AGENT_JOBNAME = 'Pester Test'
        Write-ProgressToHost 'Test' 6>&1 | Should -Match "$([Regex]::Escape('##[info]'))"
        $env:AGENT_JOBNAME = $prevJobName
    }

    It 'should output to the verbose steam if $ProgressPreference != Continue' {
        $currentProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Write-ProgressToHost 'Test' 6>&1 | Should -Not -Match 'Test'
        Write-ProgressToHost 'Test' -Verbose 4>&1 | Should -Match 'Test'
        $ProgressPreference = $currentProgressPreference
    }
}