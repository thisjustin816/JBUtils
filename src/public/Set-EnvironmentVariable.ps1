<#
.SYNOPSIS
Sets an environment variable.

.DESCRIPTION
Sets an environment variable.

.PARAMETER Name
Name of the environment variable.

.PARAMETER Value
Parameter description

.PARAMETER Scope
Environment scope: Machine, Process, or User.

.PARAMETER Append
Appends the given value to the variable instead of replacing it.

.PARAMETER Delete
Deletes the named environment variable.

.PARAMETER PassThru
Outputs an environment variable object to the pipeline.

.PARAMETER Force
Sets the value even if it already exists in the environment variable, and doesn't prompt to modify the Path.

.EXAMPLE
Set-EnvironmentVariable -Name PATH -Value 'C:/Program Files/NuGet' -Scope Machine -Append
Adds 'C:/Program Files/NuGet' to the System PATH variable.
.NOTES
N/A
#>

function Set-EnvironmentVariable {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Set')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Name,

        [Parameter(ParameterSetName = 'Set', ValueFromPipelineByPropertyName = $true)]
        [String]$Value,

        [ValidateSet('Machine', 'Process', 'User')]
        [String]$Scope = 'Process',

        [Parameter(ParameterSetName = 'Set')]
        [Switch]$Append,

        [Parameter(ParameterSetName = 'Delete')]
        [Switch]$Delete,

        [Parameter(ParameterSetName = 'Set')]
        [Switch]$PassThru,

        [Parameter(ParameterSetName = 'Set')]
        [Switch]$Force
    )

    begin {
        if ($Scope -eq 'Machine') {
            $null = Test-PSEnvironment -CheckAdmin -Exit
        }
    }

    process {
        if ($Delete) {
            if ($PSCmdlet.ShouldProcess("$($Scope):$Name", 'Delete') -or $Force) {
                [System.Environment]::SetEnvironmentVariable($Name, $null, $Scope)
                Set-Item -Path "env:$Name" -Value $null -Force
            }
            return
        }

        $envVariableValue = Get-EnvironmentVariable -Name $Name -Scope $Scope |
            Select-Object -ExpandProperty Value
        if ($null -eq $envVariableValue) {
            Write-Verbose -Message "Environment variable $($Scope):$Name does not exist."
            $envVariableValue = ''
            $isNewVar = $true
        }

        $isNotArray = $envVariableValue -notmatch [System.IO.Path]::PathSeparator
        $isNotEqualToEnvValue = $envVariableValue.Trim() -ne $Value.Trim()
        $isNotArrayIsNotEqual = $isNotArray -and $isNotEqualToEnvValue
        $isArray = $envVariableValue -match [System.IO.Path]::PathSeparator
        $isNotValueInEnvArray = $envVariableValue -notmatch [Regex]::Escape($Value)
        $isArrayIsNotMatching = $isArray -and $isNotValueInEnvArray

        if ($Force -or $isNotArrayIsNotEqual -or $isArrayIsNotMatching) {
            if ($Name -eq 'PATH' -and (!$Append) -and (!$Force)) {
                Write-Warning -Message (
                    "This will overwrite all entries in the $($Scope):PATH variable with: $Value"
                )
                $shouldAppend = Read-Host -Prompt "Should $Value be appended instead? (y/n)"
                if ($shouldAppend -eq 'y') {
                    $Append = $true
                }
            }

            # Ensure that the existing PATH variable doesn't get corrupted when appending
            $valueWithPathSeparator = if (
                $Append -and
                $Name -eq 'PATH' -and
                $Value[0] -ne [System.IO.Path]::PathSeparator
            ) {
                [System.IO.Path]::PathSeparator + $Value
            }
            else {
                $Value
            }

            $finalValue = if ($Append) {
                $envVariableValue + $valueWithPathSeparator
            }
            else {
                $valueWithPathSeparator
            }

            if ($PSCmdlet.ShouldProcess("$($Scope):$Name", "Setting value to $finalValue") -or $Force) {
                [System.Environment]::SetEnvironmentVariable($Name, $finalValue, $Scope)

                if ($Name -match 'path' -and $isArray) {
                    $scopedValue = (
                        Get-Item -Path "env:$($Name.ToUpper())"
                    ).Value.Split([System.IO.Path]::PathSeparator)
                    $newValue = $finalValue.Split([System.IO.Path]::PathSeparator)
                    if (
                        Compare-Object `
                            -ReferenceObject ( $scopedValue | Sort-Object ) `
                            -DifferenceObject ( $newValue | Sort-Object )
                    ) {
                        $combinedValue = $scopedValue + $newValue
                        $finalValue = $combinedValue -join [System.IO.Path]::PathSeparator
                    }
                }

                if (
                    $Scope -eq 'Process' -or
                    $isNewVar -or
                    ($Name -match 'PATH' -and $isArray)
                ) {
                    Set-Item -Path "env:$Name" -Value $finalValue -Force
                }
            }
        }
        else {
            Write-Warning -Message (
                "The environment variable $($Scope):$Name already contains a value of $Value. " +
                'Nothing was modified; use -Force to overwrite it.'
            )
        }
        if ($PassThru) {
            Get-EnvironmentVariable -Name $Name -Scope $Scope
        }
    }
}
