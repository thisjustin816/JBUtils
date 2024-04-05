<#
.SYNOPSIS
Uninstalls a program by name.

.DESCRIPTION
Uninstalls a program by name, instead of having to call its installer.

.PARAMETER Name
Name to search for. Accepts wildcard characters. Accepts pipeline input.

.EXAMPLE
Uninstall-ProgramByName -Name 'visual studio code'

.NOTES
General notes
#>

function Uninstall-ProgramByName {
    #[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Name,
        [Switch]$Wmi
    )

    begin {
        Test-PSEnvironment -MinimumVersion 5.1
    }

    process {
        $Activity = "Uninstall $Name"
        if ($Wmi) {
            $status = 'Finding the installation...'
            Write-Progress -Activity $Activity -Status $status
            $attempts = 0
            $app = @()
            do {
                $attempts++
                $uninstallError = $false
                if ($attempts -gt 1) {
                    Write-Progress -Activity $Activity -Status $status -CurrentOperation "Attempt: $attempts"
                }
                try {
                    Write-Verbose -Message 'Gathering all installed apps...'
                    $apps = Get-CimInstance -ClassName 'Win32_Product' -ErrorAction Stop
                    Write-Verbose -Message "Finding $Name to uninstall..."
                    $app += $apps | Where-Object {
                        $_.Name -match [Regex]::Escape($Name)
                    }
                }
                catch {
                    Write-Verbose -Message "Attempt $attempts failed."
                    Write-Verbose -Message $_
                    $uninstallError = $true
                }
            }
            while (($uninstallError -eq $true) -and ($attempts -le 3))
            if (!($app)) {
                Write-Progress -Activity $Activity -Completed
                Write-Warning "$Name is either not installed, or can't be found by this function."
            }
            else {
                Write-Verbose -Message "Uninstalled $Name on attempt $attempts."
            }
            foreach ($instance in $app) {
                Write-Verbose -Message "Uninstalling $($instance.Name) $($instance.Version)..."
                Write-Progress -Activity $Activity -Status "Uninstalling $($instance.Name) $($instance.Version)..."
                Invoke-CimMethod -InputObject $instance -MethodName 'Uninstall'
                Write-Progress -Activity $Activity -Completed
            }
        }
        else {
            Write-Progress -Activity $Activity -Status 'Finding the installation...'
            $programLocations = @(
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
                'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
            )
            $apps = Get-ChildItem -Path $programLocations | Get-ItemProperty | Sort-Object -Property DisplayName
            $app = @()
            $app += $apps | Where-Object {
                $_.DisplayName -match [Regex]::Escape($Name)
            }
            if (!($app)) {
                Write-Progress -Activity $Activity -Completed
                Write-Warning "$Name is either not installed, or can't be found by this function."
            }
            foreach ($instance in $app) {
                Write-Verbose -Message "Uninstalling $($instance.Name) $($instance.DisplayVersion)..."
                Write-Progress `
                    -Activity $Activity `
                    -Status "Uninstalling $($instance.Name) $($instance.DisplayVersion)..."
                $uninstallString = $instance.UninstallString
                $isExeOnly = Test-Path -LiteralPath $uninstallString
                if (!$isExeOnly) {
                    $uninstallString += ' /passive /norestart'
                    # Need to explicitly set uninstall for installers that just call themselves again to uninstall
                    $uninstallString = $uninstallString.Replace('/I', '/uninstall ')
                }
                $process = Start-Process -FilePath cmd -ArgumentList ('/c', $uninstallString) -PassThru
                $process | Wait-Process
                $process | Select-Object -Property ProcessName, ExitCode
                Write-Progress -Activity $Activity -Completed
            }
        }
    }
}
