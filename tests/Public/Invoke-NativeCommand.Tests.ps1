Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        $Script:PwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    }

    It 'should stream native output and not throw when the command succeeds' {
        $parameters = @{
            FilePath       = $PwshPath
            ArgumentList   = @('-NoProfile', '-Command', "'native output'; exit 0")
            FailureMessage = 'Command failed.'
        }

        Invoke-NativeCommand @parameters | Should -Be 'native output'
    }

    It 'should throw the supplied message and exit code when the command fails' {
        $parameters = @{
            FilePath       = $PwshPath
            ArgumentList   = @('-NoProfile', '-Command', 'exit 7')
            FailureMessage = 'Command failed.'
        }

        { Invoke-NativeCommand @parameters } |
            Should -Throw 'Command failed. Exit code: 7'
    }

    It 'should default the failure message to one naming the command' {
        $parameters = @{
            FilePath     = $PwshPath
            ArgumentList = @('-NoProfile', '-Command', 'exit 5')
        }

        { Invoke-NativeCommand @parameters } |
            Should -Throw "'$PwshPath' failed. Exit code: 5"
    }

    It 'should run in the requested directory and restore the caller location' {
        $workingDirectory = Join-Path $TestDrive 'working'
        $null = New-Item -ItemType Directory -Path $workingDirectory
        $testScript = Join-Path $TestDrive 'verify-location.ps1'
        Set-Content -Path $testScript -Value (
            'if ((Get-Location).Path -ne $args[0]) { exit 9 }'
        )
        $callerLocation = (Get-Location).Path
        $parameters = @{
            FilePath         = $PwshPath
            ArgumentList     = @('-NoProfile', '-File', $testScript, $workingDirectory)
            FailureMessage   = 'Wrong working directory.'
            WorkingDirectory = $workingDirectory
        }

        Invoke-NativeCommand @parameters

        (Get-Location).Path | Should -Be $callerLocation
    }

    It 'should restore the caller location when the command fails' {
        $workingDirectory = Join-Path $TestDrive 'failing'
        $null = New-Item -ItemType Directory -Path $workingDirectory
        $callerLocation = (Get-Location).Path
        $parameters = @{
            FilePath         = $PwshPath
            ArgumentList     = @('-NoProfile', '-Command', 'exit 3')
            FailureMessage   = 'Command failed.'
            WorkingDirectory = $workingDirectory
        }

        { Invoke-NativeCommand @parameters } | Should -Throw

        (Get-Location).Path | Should -Be $callerLocation
    }
}
