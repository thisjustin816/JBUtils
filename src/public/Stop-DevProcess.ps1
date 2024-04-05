<#
.SYNOPSIS
Stops any processes that may interfere with a product build.

.DESCRIPTION
Stops any processes that may interfere with a product build, includes Visual Studio and Selenium ChromeDriver by
default.

.PARAMETER Optional
A list of process names that will prompt to stop before stopping them. Always includes Visual Studio.

.PARAMETER Required
A list of process names that will be stopped without prompting. Always includes Selenium ChromeDriver.

.EXAMPLE
Stop-DevProcess

.EXAMPLE
Stop-DevProcess -Required @('*chromedriver', 'foviawebsdk')
#>
function Stop-DevProcess {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
    param (
        [Parameter(Position = 0)]
        [string[]]$Optional,
        [string[]]$Required
    )

    # $Optional += @(
    #     'devenv'
    # )
    $Required += @(
        '*chromedriver'
    )

    Test-PSEnvironment
    foreach ($processName in $Optional) {
        $processes = @( Get-Process -Name $processName -ErrorAction SilentlyContinue )
        foreach ($process in $processes) {
            $programName = if ($process.Product) {
                $process.Product
            }
            else {
                $process.ProcessName
            }
            $nameString = "$programName [$($process.Id)]"
            $stop = Read-Host -Prompt (
                "$nameString is running and could cause issues. Would you like to stop it? (y/n):"
            )
            if ($stop.ToLower() -eq 'y') {
                if ($PSCmdlet.ShouldProcess($process, 'Stop-Process')) {
                    $process | Stop-ProcessTree
                }
            }
        }
    }
    foreach ($processName in $Required) {
        $processes = @( Get-Process -Name $processName -ErrorAction SilentlyContinue )
        foreach ($process in $processes) {
            $programName = if ($process.Product) {
                $process.Product
            }
            else {
                $process.ProcessName
            }
            $nameString = "$programName [$($process.Id)]"
            $stopMessage = "$nameString is running and will be stopped."
            Write-Host -Object $stopMessage
            if ($PSCmdlet.ShouldProcess($process, 'Stop-Process')) {
                $process | Stop-ProcessTree
            }
        }
    }
}
