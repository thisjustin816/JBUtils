Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Start-Stopwatch.ps1
    }

    It 'should start a stopwatch' {
        $sw = Start-Stopwatch
        Start-Sleep -Milliseconds 100
        $sw.ElapsedMilliseconds | Should -BeGreaterThan 0
        $sw.IsRunning | Should -Be $True
    }

    It 'should resume a stopped stopwatch' {
        $sw = Start-Stopwatch
        Start-Sleep -Milliseconds 100
        $sw.Stop()
        $stoppedMs = $sw.ElapsedMilliseconds
        $sw | Start-Stopwatch
        Start-Sleep -Milliseconds 100
        $sw.ElapsedMilliseconds | Should -BeGreaterThan $stoppedMs
        $sw.IsRunning | Should -Be $True
    }
}