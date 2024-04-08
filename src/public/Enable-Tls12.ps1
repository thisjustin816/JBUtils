<#
.SYNOPSIS
Changes the security protocol of the current session to 1.2.

.DESCRIPTION
Changes the security protocol of the current session to 1.2.

.EXAMPLE
Enable-Tls12
Enables TLS 1.2 for the current session.

.EXAMPLE
Enable-Tls12 -Persist
Enables TLS 1.2 machine-wide.

.LINK
https://docs.microsoft.com/en-us/troubleshoot/azure/active-directory/enable-support-tls-environment

.NOTES
N/A
#>
function Enable-Tls12 {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
    [CmdletBinding()]
    param (
        [Switch]$Persist
    )

    Write-Verbose -Message '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if ($Persist) {
        Test-PSEnvironment -CheckAdmin -Exit
        $psRegPaths = (
            'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client',
            'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
        )
        foreach ($regPath in $psRegPaths) {
            $progress = @{
                Activity = 'Modifying Registry'
                Status   = "Key: $regPath"
            }
            Write-Progress @progress
            $null = New-Item -Path $regPath -Force
            $null = New-ItemProperty -Path $regPath -Name DisabledByDefault -Value 0 -PropertyType DWord -Force
            $null = New-ItemProperty -Path $regPath -Name Enabled -Value 1 -PropertyType DWord -Force
        }

        # Use reg instead of New-ItemProperty because it's not clear how
        # to modify both the 32 and 64 bit registries via PowerShell
        $startProcess = @{
            FilePath    = 'reg'
            NoNewWindow = $true
            Wait        = $true
        }
        $regPaths = (
            'HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727',
            'HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319',
            'HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727',
            'HKLM\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319'
        )
        $regValues = (
            'SystemDefaultTlsVersions',
            'SchUseStrongCrypto'
        )
        $enable = (
            '/t',
            'REG_DWORD',
            '/d',
            '1'
        )
        $registries = (
            '/reg:32',
            '/reg:64'
        )

        $totalCommands = $regPaths.Count * $regValues.Count * $registries.Count
        $count = 0
        foreach ($regPath in $regPaths) {
            foreach ($regValue in $regValues) {
                foreach ($registry in $registries) {
                    $count++
                    $startProcess['ArgumentList'] = ( 'add', $regPath, '/f' )
                    # Start-Process @startProcess
                    $startProcess['ArgumentList'] += ( '/v', $regValue, $registry )
                    $startProcess['ArgumentList'] += $enable
                    $message = 'reg ' + ($startProcess['ArgumentList']) -join ' '
                    Write-Verbose -Message $message
                    $progress = @{
                        Activity         = 'Modifying Registry'
                        Status           = "Key: $regPath, SubKey: $regValue, Value: 1"
                        CurrentOperation = "$count/$totalCommands"
                        PercentComplete  = (($count / $totalCommands) * 100)
                    }
                    Write-Progress @progress
                    Start-Process @startProcess -RedirectStandardOutput "$env:TEMP/stdout.log"
                }
            }
        }
        Write-Progress @progress -Completed
    }
}
