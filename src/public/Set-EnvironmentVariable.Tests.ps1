[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
[CmdletBinding()]
param()
Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        $script:isAdmin = $true
        try {
            Test-PSEnvironment -ErrorAction SilentlyContinue
        }
        catch {
            $script:isAdmin = $false
        }
        Write-Host -Object "##[info] Running tests as admin: $($script:isAdmin)"

        . $PSScriptRoot/Get-PSVersion.ps1
        . $PSScriptRoot/Get-EnvironmentVariable.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1
        . $PSScriptRoot/Set-EnvironmentVariable.ps1

        <#
        .SYNOPSIS
        Clears variables set up for tests
        #>
        function Clear-TestEnvVar {
            foreach ($var in ('PesterEnvVar', 'ScopeTest')) {
                foreach ($scope in 'Machine', 'User', 'Process') {
                    if ($script:isAdmin -or $scope -ne 'Machine') {
                        Write-Host -Object "##[info] Clearing ENV var $var at scope $scope..."
                        [System.Environment]::SetEnvironmentVariable($var, $null, $scope)
                    }
                }
            }
        }

        Mock Test-PSEnvironment

        Mock Get-EnvironmentVariable

        Mock Read-Host {
            Write-Host -Object 'Changing $Append to $true'
            'y'
        }

        $script:existingPath = $env:PATH
    }

    It "should create a variable if it doesn't exist already" {
        Clear-TestEnvVar
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value'
        $env:PesterEnvVar | Should -BeExactly 'some value'
    }

    It 'should not output any objects without PassThru' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' | Should -Be $null
    }

    It 'should output an object if PassThru is specified' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' -PassThru |
            ForEach-Object -Process {
                $_.Name | Should -Be 'PesterEnvVar'
                $_.Value | Should -Be 'some value'
                $_.Scope | Should -Be 'Process'
            }
    }

    Context 'overwrite value' {
        BeforeAll {
            Mock Get-EnvironmentVariable {
                [PSCustomObject]@{
                    Name  = $Name
                    Value = 'some value'
                    Scope = $Scope
                }
            }
        }

        It 'should append a value with -Append' {
            Set-EnvironmentVariable -Name PesterEnvVar -Value ' was appended' -Append
            $env:PesterEnvVar | Should -BeExactly 'some value was appended'
        }

        It 'should not overwrite the variable if it has the same value' {
            Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' 3>&1 | Should -Match 'already contains'
        }

        It 'should overwrite the variable if it only contains the same value' {
            Set-EnvironmentVariable -Name PesterEnvVar -Value 'some' 3>&1 | Should -BeNullOrEmpty
        }

        It 'should overwrite a single value with -Force' {
            Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' -Force 3>&1 | Should -BeNullOrEmpty
        }
    }

    Context 'PATH handling' {
        BeforeAll {
            Mock Get-EnvironmentVariable {
                [PSCustomObject]@{
                    Name  = $Name
                    Value = 'first/path;second/path'
                    Scope = $Scope
                }
            }
        }

        It 'should not overwrite an array value if the array contains the new value' {
            Set-EnvironmentVariable -Name PATH -Value 'second/path' 3>&1 | Should -Match 'already contains'
        }

        It 'Should overwrite an array value with -Force' {
            Set-EnvironmentVariable -Name PATH -Value 'second/path' -Force 3>&1 | Should -BeNullOrEmpty
        }
    }

    Context 'scope handling' {
        BeforeDiscovery {
            $global:scopes = @(
                @{ Scope = 'Process' }
                @{ Scope = 'User' }
            )
            if ($script:isAdmin) {
                $global:scopes += @{ Scope = 'Machine' }
            }
        }

        BeforeAll {
            Mock Get-EnvironmentVariable {
                [PSCustomObject]@{
                    Name  = $Name
                    Value = 'some value'
                    Scope = $Scope
                }
            }
        }

        It 'should only write to the scope that is specified: <Scope>' -TestCases $global:scopes {
            param ($Scope)
            Clear-TestEnvVar
            Set-EnvironmentVariable -Name ScopeTest -Value "this is a $Scope value" -Scope $scope
            [System.Environment]::GetEnvironmentVariable('ScopeTest', $Scope) |
                Should -Be "this is a $Scope value"
            foreach ($otherScope in @(
                $global:scopes.Values |
                    Where-Object { $_ -ne $Scope -and $_ -ne 'Process' }
            )) {
                [System.Environment]::GetEnvironmentVariable('ScopeTest', $otherScope) | Should -Be $null
            }
        }

        It 'should throw an error for an invalid scope' {
            { Set-EnvironmentVariable -Name ScopeTest -Value 'this is a outofscope value' -Scope 'OutOfScope' } |
                Should -Throw
        }
    }

    Context 'PATH append' {
        BeforeAll {
            Mock Get-EnvironmentVariable {
                [PSCustomObject]@{
                    Name  = $Name
                    Value = 'first/path'
                    Scope = $Scope
                }
            }
        }

        It 'should prompt to append if not already specified with the PATH variable' {
            Set-EnvironmentVariable -Name PATH -Value ';second/path'
            $env:PATH | Should -Be 'first/path;second/path'
        }
    }

    Context '2 item PATH' {
        BeforeAll {
            Mock Get-EnvironmentVariable {
                [PSCustomObject]@{
                    Name  = $Name
                    Value = 'first/path;second/path'
                    Scope = $Scope
                }
            }
        }

        It 'should add a semicolon if not specified when appending to PATH' {
            Set-EnvironmentVariable -Name PATH -Value 'third/path'
            $env:PATH | Should -Be 'first/path;second/path;third/path'
        }
    }

    Context '3 item PATH' {
        BeforeAll {
            Mock Get-EnvironmentVariable {
                [PSCustomObject]@{
                    Name  = $Name
                    Value = 'first/path;second/path;third/path'
                    Scope = $Scope
                }
            }
        }

        It 'should add a semicolon if not specified when prompted to append to PATH' {
            Set-EnvironmentVariable -Name PATH -Value 'fourth/path' -Append
            $env:PATH | Should -Be 'first/path;second/path;third/path;fourth/path'
        }

        It 'should delete the variable if -Delete is used' {
            Set-EnvironmentVariable -Name PATH -Delete
            $env:PATH | Should -Be $null
            Get-ChildItem -Path 'env:' | Where-Object -Property Name -EQ PATH | Should -Be $null
        }

        It "should return the original object even if it didn't overwrite the variable" {
            Set-EnvironmentVariable -Name PATH -Value 'first/path;second/path;third/path' |
                ForEach-Object -Process {
                    $_.Name | Should -Not -BeNullOrEmpty
                    $_.Value | Should -Not -BeNullOrEmpty
                    $_.Scope | Should -Not -BeNullOrEmpty
                }
        }
    }

    Context 'misc' {
        BeforeAll {
            Mock Get-EnvironmentVariable {
                if ($Scope -eq 'User') {
                    $value = 'user value'
                }
                if ($Scope -eq 'Process') {
                    $value = 'process value'
                }
                foreach ($item in $Name) {
                    [PSCustomObject]@{
                        Name  = $item
                        Value = $value
                        Scope = $Scope
                    }
                }
            }
        }

        It 'should accept pipeline input from Get-EnvironmentVariable' {
            Get-EnvironmentVariable -Name 'PesterEnvVar' -Scope 'User' | Set-EnvironmentVariable -Scope 'Process'
            $env:PesterEnvVar | Should -Be 'user value'
        }

        It 'should not set the variable is -WhatIf is passed' {
            $env:PesterEnvVar = 'original value'
            Set-EnvironmentVariable -Name 'PesterEnvVar' -Value 'modified value' -WhatIf
            $env:PesterEnvVar | Should -Be 'original value'
        }
    }

    AfterAll {
        Clear-TestEnvVar
        $env:PATH = $script:existingPath
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    BeforeDiscovery {
        try {
            Test-PSEnvironment -ErrorAction SilentlyContinue
            $script:isAdmin = $true
        }
        catch {
            $script:isAdmin = $false
        }

        $script:allScopes = @(
            @{ Scope = 'Process' },
            @{ Scope = 'User' }
        )
        if($script:isAdmin) {
            $script:allScopes += @{ Scope = 'Machine' }
        }
    }


    BeforeAll {
        Write-Host -Object "##[info] Running tests as admin: $($script:isAdmin)"

        . $PSScriptRoot/Get-PSVersion.ps1
        . $PSScriptRoot/Get-EnvironmentVariable.ps1
        . $PSScriptRoot/Test-PSEnvironment.ps1
        . $PSScriptRoot/Set-EnvironmentVariable.ps1

        <#
        .SYNOPSIS
        Clears variables set up for tests
        #>
        function Clear-TestEnvVar {
            foreach ($var in ('PesterEnvVar', 'ScopeTest')) {
                foreach ($scope in 'Machine', 'User', 'Process') {
                    if ($script:isAdmin -or $scope -ne 'Machine') {
                        Write-Host -Object "##[info] Clearing ENV var $var at scope $scope..."
                        [System.Environment]::SetEnvironmentVariable($var, $null, $scope)
                    }
                }
            }
        }

        Mock Read-Host {
            Write-Host -Object 'Changing $Append to $true'
            'y'
        }

        $script:existingPath = $env:PATH
    }

    It "should create a variable if it doesn't exist already" {
        Clear-TestEnvVar
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value'
        $env:PesterEnvVar | Should -BeExactly 'some value'
    }

    It 'should not output any objects without PassThru' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' | Should -Be $null
    }

    It 'should output an object if PassThru is specified' {
        Clear-TestEnvVar
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' -PassThru |
            ForEach-Object -Process {
                $_.Name | Should -Be 'PesterEnvVar'
                $_.Value | Should -Be 'some value'
                $_.Scope | Should -Be 'Process'
            }
    }

    It 'should append a value with -Append' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' -Force
        Set-EnvironmentVariable -Name PesterEnvVar -Value ' was appended' -Append
        $env:PesterEnvVar | Should -BeExactly 'some value was appended'
    }

    It 'should not overwrite the variable if it has the same value' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' -Force
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' 3>&1 | Should -Match 'already contains'
    }

    It 'should overwrite the variable if it only contains the same value' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' -Force
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some' 3>&1 | Should -BeNullOrEmpty
    }

    It 'should overwrite a single value with -Force' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'some value' -Force 3>&1 | Should -BeNullOrEmpty
    }

    Context '2 item PATH' {
        BeforeEach {
            $env:PATH = 'first/path;second/path'
        }

        It 'should not overwrite an array value if the array contains the new value' {
            Set-EnvironmentVariable -Name PATH -Value 'second/path' 3>&1 | Should -Match 'already contains'
        }

        It 'Should overwrite an array value with -Force' {
            Set-EnvironmentVariable -Name PATH -Value 'second/path' -Force 3>&1 | Should -BeNullOrEmpty
        }

        AfterAll {
            $env:PATH = $script:existingPath
        }
    }

    It 'should only write to the scope that is specified: <Scope>' -TestCases $global:scopes {
        param ($Scope)
        Clear-TestEnvVar
        Set-EnvironmentVariable -Name ScopeTest -Value "this is a $Scope value" -Scope $Scope
        [System.Environment]::GetEnvironmentVariable('ScopeTest', $Scope) |
            Should -Be "this is a $Scope value"
        foreach ($otherScope in @(
            $global:scopes.Values |
                Where-Object { $_ -ne $Scope -and $_ -ne 'Process' } 
        )) {
            [System.Environment]::GetEnvironmentVariable('ScopeTest', $otherScope) | Should -Be $null
        }
    }

    Context 'append PATH' {
        BeforeAll {
            $env:PATH = 'first/path'
        }

        It 'should prompt to append if not already specified with the PATH variable' {
            Set-EnvironmentVariable -Name PATH -Value ';second/path'
            $env:PATH | Should -Be 'first/path;second/path'
        }

        It 'should add a semicolon if not specified when appending to PATH' {
            Set-EnvironmentVariable -Name PATH -Value 'third/path'
            $env:PATH | Should -Be 'first/path;second/path;third/path'
        }

        It 'should add a semicolon if not specified when prompted to append to PATH' {
            Set-EnvironmentVariable -Name PATH -Value 'fourth/path' -Append
            $env:PATH | Should -Be 'first/path;second/path;third/path;fourth/path'
        }

        It 'should delete the variable if -Delete is used' {
            Set-EnvironmentVariable -Name PATH -Delete
            $env:PATH | Should -Be $null
            Get-ChildItem -Path 'env:' | Where-Object -Property Name -EQ PATH | Should -Be $null
        }

        AfterAll {
            $env:PATH = $script:existingPath
        }
    }

    Context 'large strings' {
        BeforeAll {
            $script:userPath = Get-EnvironmentVariable -Name PATH -Scope User | Select-Object -ExpandProperty Value
        }

        It 'should handle large strings for PATH' {
            Set-EnvironmentVariable -Name PATH -Value $script:userPath -Force
            $env:PATH | Should -Be $script:userPath
        }
        It "should return the original object even if it didn't overwrite the variable" {
            Set-EnvironmentVariable -Name PATH -Value $script:userPath |
                ForEach-Object -Process {
                    $_.Name | Should -Not -BeNullOrEmpty
                    $_.Value | Should -Not -BeNullOrEmpty
                    $_.Scope | Should -Not -BeNullOrEmpty
                }
        }
    }

    It 'should accept pipeline input from Get-EnvironmentVariable' {
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'user value' -Scope User
        Get-EnvironmentVariable -Name PesterEnvVar -Scope 'User' | Set-EnvironmentVariable -Scope 'Process'
        $env:PesterEnvVar | Should -Be 'user value'
    }

    It 'should not set the variable is -WhatIf is passed' {
        $env:PesterEnvVar = 'original value'
        Set-EnvironmentVariable -Name PesterEnvVar -Value 'modified value' -WhatIf
        $env:PesterEnvVar | Should -Be 'original value'
    }

    Context 'When an environment variable is new' {
        BeforeAll {
            $script:newGuid = ( New-Guid ).ToString().Replace('-', '').ToUpper() 
        }

        It 'at <Scope> it should be instantly available' -TestCases $script:allScopes {
            param ($Scope)
            $varName = $Scope + "_" + $script:newGuid
            Set-EnvironmentVariable -Name $varName -Value 'test value' -Scope $Scope -Force
            ( Get-ChildItem -Path "env:$varName" ).Value | Should -Be 'test value'
        }

        AfterAll {
            foreach ($scope in $script:allScopes) {
                Set-EnvironmentVariable -Name ($Scope + "_" + $script:newGuid) -Delete
            }
        }
    }

    AfterAll {
        Clear-TestEnvVar
        $env:PATH = $script:existingPath
        if ( Get-Command -Name Update-SessionEnvironment -ErrorAction SilentlyContinue ) {
            Update-SessionEnvironment
        }
    }
}
