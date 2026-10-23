<#
.SYNOPSIS
Internal: writes a value to a process, user, or machine environment scope.
#>
function Set-EnvironmentVariableValue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The public command performs ShouldProcess before calling this private boundary.'
    )]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Name,
        [AllowNull()]
        [Object]$Value,
        [EnvironmentVariableTarget]$Scope
    )

    # Environment providers only write process variables; .NET also supports persistent scopes.
    [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
}
