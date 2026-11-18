Describe 'Exact native command environments' -Tag 'Unit' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
    BeforeAll {
        . $PSScriptRoot/../../src/Private/Invoke-ProcessExchange.ps1
        . $PSScriptRoot/../../src/Public/Invoke-NativeCommand.ps1
        $Script:ExactExecutable = (Get-Command pwsh -ErrorAction Stop).Source

        function New-ExactFixture {
            param([String]$Code, [AllowEmptyString()][String]$InputText = '')
            $environment = @{}
            $runtime = Get-Item -LiteralPath ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
            if ($runtime.Parent.Name -eq 'Microsoft.NETCore.App' -and $runtime.Parent.Parent.Name -eq 'shared') {
                $environment.DOTNET_ROOT = $runtime.Parent.Parent.Parent.FullName
            }
            if ($IsWindows) { $environment.SystemRoot = $env:SystemRoot }
            @{
                FilePath         = $ExactExecutable
                ArgumentList     = @(
                    '-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand'
                    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code))
                )
                WorkingDirectory = $TestDrive
                ExactEnvironment = $environment
                InputText        = $InputText
            }
        }
    }

    It 'excludes undeclared parent variables and preserves null and empty values without changing the parent' {
        $previous = $env:JBUTILS_EXACT_PARENT
        try {
            $env:JBUTILS_EXACT_PARENT = 'parent-canary'
            $code = @'
[Console]::Write((@{
    Parent = [Environment]::GetEnvironmentVariable('JBUTILS_EXACT_PARENT')
    Selected = $env:SELECTED
    Removed = Test-Path Env:REMOVED
    Empty = Test-Path Env:EMPTY
} | ConvertTo-Json -Compress))
'@
            $parameters = New-ExactFixture -Code $code
            $parameters.ExactEnvironment.SELECTED = 'selected-canary'
            $parameters.ExactEnvironment.REMOVED = $null
            $parameters.ExactEnvironment.EMPTY = ''
            $result = (Invoke-NativeCommand @parameters) -join '' | ConvertFrom-Json
            $result.Parent | Should -BeNullOrEmpty
            $result.Selected | Should -BeExactly 'selected-canary'
            $result.Removed | Should -BeFalse
            if ($PSVersionTable.PSVersion -ge [Version]'7.5') { $result.Empty | Should -BeTrue }
            $env:JBUTILS_EXACT_PARENT | Should -BeExactly 'parent-canary'
        }
        finally { $env:JBUTILS_EXACT_PARENT = $previous }
    }

    It 'passes private stdin while draining both pipes beyond protocol limits' {
        $code = @'
1..80 | ForEach-Object {
    [Console]::Out.Write(('o' * 4096))
    [Console]::Error.Write(('e' * 4096))
}
$inputText = [Console]::In.ReadToEnd()
[Console]::Write('|INPUT=' + $inputText.Length)
'@
        $parameters = New-ExactFixture -Code $code -InputText ('x' * 1048576)
        $result = (Invoke-NativeCommand @parameters) -join ''
        ([Regex]::Matches($result, 'o')).Count | Should -Be (80 * 4096)
        ([Regex]::Matches($result, 'e')).Count | Should -Be (80 * 4096)
        $result.Contains('|INPUT=1048576') | Should -BeTrue
    }

    It 'streams output before exit and decodes UTF-8 split across writes without a newline' {
        $code = @'
$stream = [Console]::OpenStandardOutput()
$bytes = [Text.Encoding]::UTF8.GetBytes([String][Char]0x03BB)
$stream.Write($bytes, 0, 1)
$stream.Flush()
Start-Sleep -Milliseconds 80
$stream.Write($bytes, 1, 1)
$stream.Flush()
Start-Sleep -Seconds 2
[Console]::Write('done')
'@
        $parameters = New-ExactFixture -Code $code
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $receivedAt = [Collections.Generic.List[Int64]]::new()
        $result = @(Invoke-NativeCommand @parameters | ForEach-Object {
            $receivedAt.Add($timer.ElapsedMilliseconds)
            $_
        })
        ($result -join '') | Should -BeExactly (([String][Char]0x03BB) + 'done')
        $receivedAt[0] | Should -BeLessThan ($timer.ElapsedMilliseconds - 1000)
    }

    It 'keeps literal arguments and the working directory separate from invocation code' {
        $script = Join-Path $TestDrive 'literal arguments.ps1'
        Set-Content -LiteralPath $script -Value '[Console]::Write((@($args[0], (Get-Location).Path) | ConvertTo-Json))'
        $literal = 'spaces "quotes" $(throw 1) & | %PATH%'
        $parameters = New-ExactFixture -Code ''
        $parameters.ArgumentList = @('-NoProfile', '-File', $script, $literal)
        $result = (Invoke-NativeCommand @parameters) -join '' | ConvertFrom-Json
        $result[0] | Should -BeExactly $literal
        $result[1] | Should -BeExactly (Get-Item -LiteralPath $TestDrive).FullName
    }

    It 'rejects <Kind> before starting or disclosing private input' -ForEach @(
        @{ Kind = 'oversized input'; FixtureInput = 'private-canary'; Limit = 1; Category = 'InputLimitExceeded' }
        @{
            Kind = 'invalid UTF-8'
            FixtureInput = ([String][Char]0xD800)
            Limit = 100
            Category = 'InvalidInputEncoding'
        }
    ) {
        $marker = Join-Path $TestDrive 'started'
        $parameters = New-ExactFixture -Code "Set-Content '$marker' started" -InputText $FixtureInput
        $parameters.MaxInputBytes = $Limit
        { Invoke-NativeCommand @parameters } | Should -Throw "*${Category}*"
        Test-Path -LiteralPath $marker | Should -BeFalse
    }

    It 'preserves the supplied message and exit code' {
        $parameters = New-ExactFixture -Code 'exit 7'
        $parameters.FailureMessage = 'Application failed.'
        { Invoke-NativeCommand @parameters } | Should -Throw 'Application failed. Exit code: 7'
    }

    It 'applies backpressure while the caller pauses output consumption' {
        $marker = Join-Path $TestDrive 'producer-finished'
        $escapedMarker = $marker.Replace("'", "''")
        $code = "[Console]::Write(('x' * 8388608)); Set-Content -LiteralPath '$escapedMarker' done"
        $parameters = New-ExactFixture -Code $code
        $state = @{ First = $true; Count = 0 }
        Invoke-NativeCommand @parameters | ForEach-Object {
            if ($state.First) {
                $state.First = $false
                Start-Sleep -Milliseconds 500
                Test-Path -LiteralPath $marker | Should -BeFalse
            }
            $state.Count += $_.Length
        }
        $state.Count | Should -Be 8388608
        Test-Path -LiteralPath $marker | Should -BeTrue
    }

    It 'keeps simultaneous complete environments separate' {
        $script = {
            param($SourceRoot, $Parameters)
            . (Join-Path $SourceRoot 'Private/Invoke-ProcessExchange.ps1')
            . (Join-Path $SourceRoot 'Public/Invoke-NativeCommand.ps1')
            Invoke-NativeCommand @Parameters
        }
        $firstParameters = New-ExactFixture -Code 'Start-Sleep -Milliseconds 100; [Console]::Write($env:SELECTED)'
        $secondParameters = New-ExactFixture -Code '[Console]::Write($env:SELECTED)'
        $firstParameters.ExactEnvironment.SELECTED = 'first'
        $secondParameters.ExactEnvironment.SELECTED = 'second'
        $source = (Get-Item -LiteralPath "$PSScriptRoot/../../src").FullName
        $first = [PowerShell]::Create()
        $second = [PowerShell]::Create()
        try {
            $null = $first.AddScript($script).AddArgument($source).AddArgument($firstParameters)
            $null = $second.AddScript($script).AddArgument($source).AddArgument($secondParameters)
            $firstRun = $first.BeginInvoke()
            $secondRun = $second.BeginInvoke()
            ($first.EndInvoke($firstRun) -join '') | Should -BeExactly 'first'
            ($second.EndInvoke($secondRun) -join '') | Should -BeExactly 'second'
            $first.HadErrors | Should -BeFalse
            $second.HadErrors | Should -BeFalse
        }
        finally {
            $first.Dispose()
            $second.Dispose()
        }
    }

    It 'does not disclose invalid environment values or startup details' {
        $parameters = New-ExactFixture -Code ''
        $parameters.ExactEnvironment['invalid=name'] = 'private-environment-canary'
        { Invoke-NativeCommand @parameters } | Should -Throw '*InvalidEnvironment*'
        $parameters.ExactEnvironment = @{}
        $parameters.FilePath = 'nonexistent-private-executable-canary'
        { Invoke-NativeCommand @parameters } | Should -Throw "'$($parameters.FilePath)' failed.*StartFailed*"
        $parameters.FailureMessage = 'Application failed.'
        { Invoke-NativeCommand @parameters } | Should -Throw 'Application failed. Native command failed: StartFailed.'
    }

    It 'rejects combining complete and inherited environment modes' {
        $parameters = New-ExactFixture -Code ''
        { Invoke-NativeCommand @parameters -Environment @{} } | Should -Throw
    }

    It 'cancels during <State> without waiting for normal exit' -ForEach @(
        @{ State = 'idle'; Code = 'Start-Sleep -Seconds 60'; FixtureInput = '' }
        @{ State = 'blocked stdin'; Code = 'Start-Sleep -Seconds 60'; FixtureInput = ('x' * 1048576) }
        @{ State = 'continuous output'; Code = "while (`$true) { [Console]::Write('x' * 4096) }"; FixtureInput = '' }
    ) {
        $parameters = New-ExactFixture -Code $Code -InputText $FixtureInput
        $cancel = [Threading.CancellationTokenSource]::new()
        try {
            $cancel.CancelAfter(1000)
            $timer = [Diagnostics.Stopwatch]::StartNew()
            {
                Invoke-NativeCommand @parameters -CancellationToken $cancel.Token | Out-Null
            } | Should -Throw '*Cancelled*'
            $timer.Elapsed.TotalSeconds | Should -BeLessThan 5
        }
        finally { $cancel.Dispose() }
    }

    It 'does not impose the private protocol runtime deadline' -Tag 'HostIntegration' {
        $parameters = New-ExactFixture -Code "Start-Sleep -Seconds 31; [Console]::Write('completed')"
        ((Invoke-NativeCommand @parameters) -join '') | Should -BeExactly 'completed'
    }

    It 'terminates attached descendants on pipeline stop while preserving an unrelated process' {
        $marker = Join-Path $TestDrive 'process-tree.json'
        $sleepCode = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('Start-Sleep -Seconds 60'))
        $escapedExecutable = $ExactExecutable.Replace("'", "''")
        $escapedMarker = $marker.Replace("'", "''")
        $code = @"
`$child = Start-Process -FilePath '$escapedExecutable' -ArgumentList @(
    '-NoProfile', '-NonInteractive', '-EncodedCommand', '$sleepCode'
) -PassThru
@{ Parent = `$PID; Child = `$child.Id } | ConvertTo-Json | Set-Content -LiteralPath '$escapedMarker'
Start-Sleep -Seconds 60
"@
        $parameters = New-ExactFixture -Code $code -InputText ('x' * 1048576)
        $unrelated = Start-Process -FilePath $ExactExecutable -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-EncodedCommand', $sleepCode
        ) -PassThru
        $shell = [PowerShell]::Create()
        $identities = $null
        try {
            $script = {
                param($SourceRoot, $Parameters)
                . (Join-Path $SourceRoot 'Private/Invoke-ProcessExchange.ps1')
                . (Join-Path $SourceRoot 'Public/Invoke-NativeCommand.ps1')
                Invoke-NativeCommand @Parameters
            }
            $source = (Get-Item -LiteralPath "$PSScriptRoot/../../src").FullName
            $null = $shell.AddScript($script).AddArgument($source).AddArgument($parameters)
            $running = $shell.BeginInvoke()
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            while (-not (Test-Path -LiteralPath $marker) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 25
            }
            Test-Path -LiteralPath $marker | Should -BeTrue
            $identities = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
            $timer = [Diagnostics.Stopwatch]::StartNew()
            $shell.Stop()
            $timer.Elapsed.TotalSeconds | Should -BeLessThan 5
            $running.IsCompleted | Should -BeTrue
            foreach ($identity in @($identities.Parent, $identities.Child)) {
                $deadline = [DateTime]::UtcNow.AddSeconds(3)
                do {
                    $process = Get-Process -Id $identity -ErrorAction SilentlyContinue
                    if (-not $process -or $process.HasExited) { break }
                    Start-Sleep -Milliseconds 25
                } while ([DateTime]::UtcNow -lt $deadline)
                ($null -eq $process -or $process.HasExited) | Should -BeTrue
            }
            $unrelated.Refresh()
            $unrelated.HasExited | Should -BeFalse
        }
        finally {
            $shell.Dispose()
            $unrelated | Stop-Process -Force -ErrorAction SilentlyContinue
            if ($identities) {
                foreach ($identity in @($identities.Parent, $identities.Child)) {
                    Stop-Process -Id $identity -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
