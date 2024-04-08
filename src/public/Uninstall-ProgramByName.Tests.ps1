Describe 'Integration Tests' -Tag 'Integration' -Skip:(!$script:isAdmin) {
    BeforeDiscovery {
        $script:isAdmin = Test-IsAdmin
    }

    BeforeAll {
        . $PSScriptRoot/Get-PSVersion.ps1
        . $PSScriptRoot/Test-IsAdmin.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1
        . $PSScriptRoot/Uninstall-ProgramByName.ps1

        <#
        .SYNOPSIS
        Installs Putty to use for testing.
        #>
        function Install-Putty {
            param (
                [String[]]$Url = 'https://the.earth.li/~sgtatham/putty/0.74/w32/putty-0.74-installer.msi'
            )
            foreach ($site in $Url) {
                $tmpFile = ( New-TemporaryFile ).FullName
                $currentProgressPreference = $ProgressPreference
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $site -UseBasicParsing -OutFile $tmpFile
                $ProgressPreference = $currentProgressPreference
                Start-Process -FilePath 'msiexec' -ArgumentList '/i', $tmpFile, '/qn' -Wait
                Remove-Item -Path $tmpFile -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'When using WMI: <_>' -ForEach @($false, $true) {
        BeforeAll {
            $script:useWmi = $_
        }

        It 'should uninstall an installed program by name successfully' {
            Install-Putty
            Uninstall-ProgramByName -Name 'Putty' -Wmi:$script:useWmi | Should -Not -BeNullOrEmpty
        }

        It "should not throw an error if the program to uninstall isn't found" {
            Uninstall-ProgramByName -Name 'Putty' -Wmi:$script:useWmi 3>&1 |
                Should -Match 'is either not installed'
        }

        It 'should uninstall all instances of a program' {
            Install-Putty -Url @(
                'https://the.earth.li/~sgtatham/putty/0.74/w32/putty-0.74-installer.msi',
                'https://ttyplus.com/download/mtputty_setup.exe'
            )
            Uninstall-ProgramByName -Name 'Putty' -Wmi:$script:useWmi | Should -Not -BeNullOrEmpty
            Write-Progress -Activity 'Confirming uninstall...'
            Get-CimInstance -ClassName 'Win32_Product' |
                Where-Object -FilterScript { $_.Name -match [Regex]::Escape('Putty') } |
                Should -BeNullOrEmpty
        }

        It 'should not reinstall using this function' {
            Install-Putty
            Uninstall-ProgramByName -Name 'Putty' -Wmi:$script:useWmi
            Uninstall-ProgramByName -Name 'Putty' -Wmi:$script:useWmi
            Write-Progress -Activity 'Confirming uninstall...'
            Get-CimInstance -ClassName 'Win32_Product' |
                Where-Object -FilterScript { $_.Name -match [Regex]::Escape('Putty') } |
                Should -BeNullOrEmpty
        }

        It 'should install correctly if calling uninstall first' {
            Uninstall-ProgramByName -Name 'Putty' -Wmi:$script:useWmi
            Install-Putty
            Write-Progress -Activity 'Confirming install...'
            Get-CimInstance -ClassName 'Win32_Product' |
                Where-Object -FilterScript { $_.Name -match [Regex]::Escape('Putty') } |
                Should -Not -BeNullOrEmpty
        }

        AfterAll {
            Write-Progress -Activity 'Confirming uninstall...' -Completed
        }
    }
}
