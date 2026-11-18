Describe 'Native protocol exchange' -Tag 'Unit' -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
    BeforeAll {
        foreach ($source in @('Private/Invoke-ProcessExchange.ps1', 'Public/Invoke-NativeProtocol.ps1')) {
            $path = Join-Path $PSScriptRoot '../../src' $source
            if (Test-Path -LiteralPath $path) { . $path }
        }
        $Script:ProtocolExecutable = (Get-Command pwsh -ErrorAction Stop).Source

        function New-ProtocolFixture {
            param([String]$Code, [AllowEmptyString()][String]$InputText = '')
            $runtime = Get-Item -LiteralPath ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())
            $environment = @{ TZ = 'UTC' }
            if ($runtime.Parent.Name -eq 'Microsoft.NETCore.App' -and $runtime.Parent.Parent.Name -eq 'shared') {
                $environment.DOTNET_ROOT = $runtime.Parent.Parent.Parent.FullName
            }
            if ($IsWindows) { $environment.SystemRoot = $env:SystemRoot }
            @{
                FilePath         = $ProtocolExecutable
                ArgumentList     = @(
                    '-NoLogo'
                    '-NoProfile'
                    '-NonInteractive'
                    '-EncodedCommand'
                    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code))
                )
                WorkingDirectory = $TestDrive
                Environment      = $environment
                InputText        = $InputText
            }
        }
    }

    It 'returns only captured output and removes undeclared parent variables' {
        $previous = $env:JBUTILS_PROTOCOL_CANARY
        $privateValue = 'synthetic-input-do-not-log'
        try {
            $env:JBUTILS_PROTOCOL_CANARY = 'synthetic-parent-do-not-inherit'
            $code = @'
$result = [ordered]@{
    Input = [Console]::In.ReadToEnd()
    Parent = [Environment]::GetEnvironmentVariable('JBUTILS_PROTOCOL_CANARY')
    Selected = [Environment]::GetEnvironmentVariable('SELECTED_INPUT')
}
[Console]::Write(($result | ConvertTo-Json -Compress))
'@
            $parameters = New-ProtocolFixture -Code $code -InputText $privateValue
            $parameters.Environment.SELECTED_INPUT = 'selected-value'
            $records = @(Invoke-NativeProtocol @parameters *>&1)
            $records.Count | Should -Be 1
            $records[0] | Should -BeOfType String
            $result = $records[0] | ConvertFrom-Json
            $result.Input | Should -BeExactly $privateValue
            $result.Parent | Should -BeNullOrEmpty
            $result.Selected | Should -BeExactly 'selected-value'
        }
        finally { $env:JBUTILS_PROTOCOL_CANARY = $previous }
    }

    It 'preserves separate argument boundaries without shell evaluation' {
        $parameters = New-ProtocolFixture -Code '[Console]::Write("unused")'
        $script = Join-Path $TestDrive 'argument echo.ps1'
        Set-Content `
            -LiteralPath $script `
            -Encoding utf8NoBOM `
            -Value '[Console]::Write(($args | ConvertTo-Json -Compress))'
        $parameters.ArgumentList = @('-NoProfile', '-NonInteractive', '-File', $script, 'two words', 'literal;value')
        $result = Invoke-NativeProtocol @parameters | ConvertFrom-Json
        $result[0] | Should -BeExactly 'two words'
        $result[1] | Should -BeExactly 'literal;value'
    }

    It 'rejects input by UTF-8 byte count before starting the child' {
        $marker = Join-Path $TestDrive 'input-started'
        $escapedMarker = $marker.Replace("'", "''")
        $code = "Set-Content -LiteralPath '$escapedMarker' -Value started"
        $parameters = New-ProtocolFixture -Code $code -InputText ([String][Char]0x03BB)
        $parameters.MaxInputBytes = 1
        { Invoke-NativeProtocol @parameters } | Should -Throw '*InputLimitExceeded*'
        Test-Path -LiteralPath $marker | Should -BeFalse
    }

    It 'rejects an unpaired input surrogate instead of replacing private request bytes' {
        $parameters = New-ProtocolFixture -Code '' -InputText ([String][Char]0xD800)
        { Invoke-NativeProtocol @parameters } | Should -Throw '*InvalidInputEncoding*'
    }

    It 'rejects <Kind> without returning partial private output' -ForEach @(
        @{
            Kind = 'stdout overflow'
            Code = '[Console]::Write((''x'' * 4096))'
            Limit = 'MaxOutputBytes'
            Expected = 'OutputLimitExceeded'
        }
        @{
            Kind = 'stderr overflow'
            Code = '[Console]::Error.Write((''x'' * 4096))'
            Limit = 'MaxErrorBytes'
            Expected = 'ErrorLimitExceeded'
        }
        @{
            Kind = 'unexpected stderr'
            Code = '[Console]::Error.Write(''private-stderr'')'
            Limit = ''
            Expected = 'UnexpectedErrorOutput'
        }
        @{
            Kind = 'failed exit'
            Code = '[Console]::Write(''private-stdout''); exit 9'
            Limit = ''
            Expected = 'ExitFailed'
        }
        @{
            Kind = 'invalid UTF-8'
            Code = '[Console]::OpenStandardOutput().WriteByte(255)'
            Limit = ''
            Expected = 'InvalidOutputEncoding'
        }
    ) {
        $parameters = New-ProtocolFixture -Code $Code
        if ($Limit) { $parameters[$Limit] = 64 }
        $records = @()
        $failure = try { $records = @(Invoke-NativeProtocol @parameters); $null } catch { $_ }
        $failure | Should -Not -BeNullOrEmpty
        $failure.Exception.Message | Should -Match $Expected
        $failure.Exception.Message | Should -Not -Match 'private-stdout|private-stderr'
        $records.Count | Should -Be 0
    }

    It 'bounds the whole exchange when the child refuses to read stdin' {
        $parameters = New-ProtocolFixture -Code 'Start-Sleep -Seconds 30' -InputText ('x' * 1048576)
        $parameters.TimeoutMilliseconds = 250
        $timer = [Diagnostics.Stopwatch]::StartNew()
        { Invoke-NativeProtocol @parameters } | Should -Throw '*TimedOut*'
        $timer.Elapsed.TotalSeconds | Should -BeLessThan 6
    }

    It 'honors cancellation without leaking private input' {
        $parameters = New-ProtocolFixture -Code 'Start-Sleep -Seconds 30' -InputText 'cancel-private-input'
        $cancellation = [Threading.CancellationTokenSource]::new()
        try {
            $cancellation.CancelAfter(250)
            $parameters.CancellationToken = $cancellation.Token
            { Invoke-NativeProtocol @parameters } | Should -Throw '*Cancelled*'
        }
        finally { $cancellation.Dispose() }
    }

    It 'resolves a PowerShell working-directory provider path' {
        $parameters = New-ProtocolFixture -Code '[Console]::Write([Environment]::CurrentDirectory)'
        $parameters.WorkingDirectory = 'TestDrive:'
        $expected = (Get-Item -LiteralPath 'TestDrive:').FullName.TrimEnd(
            [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar
        )
        Invoke-NativeProtocol @parameters | Should -BeExactly $expected
    }

    It 'drains both streams concurrently without returning stderr or partial stdout' {
        $code = '[Console]::Write((''o'' * 8000)); [Console]::Error.Write((''e'' * 50000))'
        $parameters = New-ProtocolFixture -Code $code
        $parameters.TimeoutMilliseconds = 5000
        { Invoke-NativeProtocol @parameters } | Should -Throw '*UnexpectedErrorOutput*'
    }

    It 'terminates the child process tree on timeout' {
        $pidPath = Join-Path $TestDrive 'descendant.pid'
        $childCode = 'Start-Sleep -Seconds 30'
        $encodedChild = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childCode))
        $quotedPath = $pidPath.Replace("'", "''")
        $quotedExecutable = $ProtocolExecutable.Replace("'", "''")
        $code = @"
`$start = [Diagnostics.ProcessStartInfo]::new('$quotedExecutable')
`$start.ArgumentList.Add('-NoProfile')
`$start.ArgumentList.Add('-NonInteractive')
`$start.ArgumentList.Add('-EncodedCommand')
`$start.ArgumentList.Add('$encodedChild')
`$child = [Diagnostics.Process]::Start(`$start)
Set-Content -LiteralPath '$quotedPath' -Value `$child.Id
Start-Sleep -Seconds 30
"@
        $parameters = New-ProtocolFixture -Code $code
        $parameters.TimeoutMilliseconds = 4000
        $childId = $null
        try {
            { Invoke-NativeProtocol @parameters } | Should -Throw '*TimedOut*'
            $pidPath | Should -Exist
            $childId = [Int32](Get-Content -LiteralPath $pidPath)
            $alive = Get-Process -Id $childId -ErrorAction Ignore
            if ($alive) { $alive.HasExited | Should -BeTrue }
        }
        finally {
            if ($childId) { Stop-Process -Id $childId -Force -ErrorAction Ignore }
        }
    }

    It 'sanitizes an executable startup failure' {
        $parameters = New-ProtocolFixture -Code '' -InputText 'private-input'
        $parameters.FilePath = Join-Path $TestDrive 'missing-private-executable'
        $failure = try { Invoke-NativeProtocol @parameters; $null } catch { $_ }
        $failure.Exception.Message | Should -Match 'StartFailed'
        $failure.Exception.Message | Should -Not -Match 'private-input|missing-private-executable'
    }
}
