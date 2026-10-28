<#
.SYNOPSIS
Internal: Exchanges the private credential protocol with a redirected subprocess.
#>
function Invoke-OsCredentialProtocol {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [Diagnostics.ProcessStartInfo]$StartInfo,
        [Parameter(Mandatory)]
        [String]$InputText
    )

    $StartInfo.UseShellExecute = $false
    $StartInfo.CreateNoWindow = $true
    $StartInfo.RedirectStandardInput = $true
    $StartInfo.RedirectStandardOutput = $true
    $StartInfo.RedirectStandardError = $true
    $StartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $StartInfo
    $inputBytes = $null
    $output = $null
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $inputBytes = [Text.Encoding]::UTF8.GetBytes($InputText)
        $process.StandardInput.BaseStream.Write($inputBytes, 0, $inputBytes.Length)
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            throw 'Credential helper timed out.'
        }
        $output = $stdout.GetAwaiter().GetResult()
        $null = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw 'Credential helper failed.'
        }
        $output
    }
    catch {
        throw 'OS credential store operation failed. Check that its session is available and unlocked.'
    }
    finally {
        if ($inputBytes) {
            [Array]::Clear($inputBytes, 0, $inputBytes.Length)
        }
        $InputText = $null
        $output = $null
        $process.Dispose()
    }
}
