<#
.SYNOPSIS
Sets the git user name and email in a given scope.

.DESCRIPTION
Sets the git user name and email in a given scope.

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
        $script:CurrentLocation = $PWD
        $script:Git = @{
            FilePath    = Get-Command -Name git.exe | Select-Object -ExpandProperty Source
            NoNewWindow = $true
            Wait        = $true
        }
        $script:Config = @(
            'config',
            "--$($Scope.ToLower())"
        )
    }

    process {
        Start-Process @script:Git -ArgumentList ($script:Config + ('http.version', 'HTTP/1.1'))
        $userEntries = @(
            @{
                ArgumentList = $script:Config + (
                    '--replace-all',
                    'user.email',
                    "`"$UserEmail`""
                )
            },
            @{
                ArgumentList = $script:Config + (
                    '--replace-all',
                    'user.name',
                    "`"$UserName`""
                )
            }
        )

        foreach ($location in $Path) {
            foreach ($user in $userEntries) {
                Start-Process @script:Git @user -WorkingDirectory $location
            }
        }
    }

    end {
        Set-Location -Path $script:CurrentLocation
    }
}