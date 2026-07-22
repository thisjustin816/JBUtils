<#
.SYNOPSIS
Gets the value of of an environment variable.

.DESCRIPTION
Gets the value of of an environment variable.

.PARAMETER Name
Name of the environment variable.

.PARAMETER Scope
Environment scope: Machine, Process, or User.

.EXAMPLE
Get-EnvironmentVariable -Name PATH -Scope User

.NOTES
N/A
#>

function Get-EnvironmentVariable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]$Name,
        [ValidateSet('Machine', 'Process', 'User')]
        [String]$Scope = 'Process'
    )

    process {
        foreach ($item in $Name) {
            [PSCustomObject]@{
                Name  = $item
                Value = [System.Environment]::GetEnvironmentVariable($item, $Scope)
                Scope = $Scope
            }
        }
    }
}
