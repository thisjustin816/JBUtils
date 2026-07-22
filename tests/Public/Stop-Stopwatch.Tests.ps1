Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Start-StopWatch.ps1
        . $PSScriptRoot/../../src/Public/Stop-Stopwatch.ps1
    }

    It 'should stop a started stopwatch' {
        $sw = Start-Stopwatch
        Start-Sleep -Milliseconds 100
        $sw | Stop-Stopwatch | ForEach-Object -Process {
            $_.IsRunning | Should -Be $false
        }
    }
}
