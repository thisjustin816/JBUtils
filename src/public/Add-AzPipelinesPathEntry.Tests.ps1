Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        . $PSScriptRoot/Add-AzPipelinesPathEntry.ps1

        if (!$env:AGENT_JOBNAME) {
            $env:AGENT_JOBNAME = 'PesterTest'
        }
    }

    It 'should add a resolved path' {
        $scriptDirectory = Get-Item -Path $PSScriptRoot
        Push-Location -Path $PSScriptRoot
        Push-Location ..
        Add-AzPipelinesPathEntry -Path $scriptDirectory.Name 6>&1 |
            Should -Be "##vso[task.prependpath]$($scriptDirectory.FullName)"
        Pop-Location
        Pop-Location
    }

    It 'should resolve a single string path starting with ;' {
        Add-AzPipelinesPathEntry -Path ";$TestDrive" 6>&1 |
            Should -Be "##vso[task.prependpath]$TestDrive"
    }

    It 'should keep actual path separators in a single string path' {
        Add-AzPipelinesPathEntry -Path ";$TestDrive;$env:LOCALAPPDATA" 6>&1 |
            Should -Be "##vso[task.prependpath]$TestDrive;$env:LOCALAPPDATA"
    }

    It 'should process an arrays of paths when some start with ;' {
        Add-AzPipelinesPathEntry -Path ";$TestDrive", $env:LOCALAPPDATA, ";$TestDrive;$env:LOCALAPPDATA" 6>&1 |
            Should -Be "##vso[task.prependpath]$TestDrive;$env:LOCALAPPDATA;$TestDrive;$env:LOCALAPPDATA"
    }

    It 'should not throw if the path does not exist' {
        { Add-AzPipelinesPathEntry -Path "$TestDrive/does/not/exist" } | Should -Not -Throw
        Add-AzPipelinesPathEntry -Path "$TestDrive/does/not/exist" 3>&1 | Should -Match 'does not exist'
    }

    AfterAll {
        if ($env:AGENT_JOBNAME -eq 'PesterTest') {
            $env:AGENT_JOBNAME = $null
        }
    }
}