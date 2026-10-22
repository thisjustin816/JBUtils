<#
.SYNOPSIS
Sets Git identity and HTTP version in the requested repositories and scope.

.DESCRIPTION
Sets Git identity and HTTP version in the requested repositories and scope.

.PARAMETER Path
Path of the repo.

.PARAMETER UserName
User name to add to the git config.

.PARAMETER UserEmail
Email to add to the git config.

.PARAMETER Scope
Scope of the git config.

.EXAMPLE
Initialize-GitConfig -UserName "Git User" -UserEmail email@example.com

.NOTES
N/A
#>
function Initialize-GitConfig {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName', 'LiteralPath')]
        [String[]]$Path = $PWD,
        [String]$UserName = $env:BUILD_REQUESTEDFOR,
        [String]$UserEmail = $env:BUILD_REQUESTEDFOREMAIL,
        [ValidateSet('System', 'Global', 'WorkTree', 'Local')]
        [String]$Scope = 'Local'
    )

    begin {
        $configuration = [ordered]@{
            'http.version' = 'HTTP/1.1'
            'user.email'   = $UserEmail
            'user.name'    = $UserName
        }
        $scopeArgument = "--$($Scope.ToLowerInvariant())"
    }

    process {
        foreach ($location in $Path) {
            foreach ($key in $configuration.Keys) {
                Invoke-NativeCommand -FilePath 'git' `
                    -ArgumentList @('config', $scopeArgument, '--replace-all', $key, $configuration[$key]) `
                    -WorkingDirectory $location `
                    -FailureMessage "Could not configure '$key' in '$location'."
            }
        }
    }
}
