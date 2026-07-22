Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        . $PSScriptRoot/../../src/Public/Write-ConsoleMessage.ps1
    }

    Context '-ForegroundColor parameter set' {
        It 'should write the message in the given color with no other formatting' {
            Mock Write-Host {}
            Write-ConsoleMessage 'hello' -ForegroundColor Cyan
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq 'hello' -and $ForegroundColor -eq [ConsoleColor]::Cyan
            }
        }

        It 'should write with no color when -ForegroundColor is omitted' {
            Mock Write-Host {}
            Write-ConsoleMessage 'plain'
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq 'plain' -and -not $ForegroundColor
            }
        }

        It 'should pass through -NoNewline' {
            Mock Write-Host {}
            Write-ConsoleMessage 'x' -ForegroundColor Green -NoNewline
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $NoNewline -eq $true }
        }
    }

    Context '-Intent parameter set' {
        It 'should write a blank line when no message is given' {
            Mock Write-Host {}
            Write-ConsoleMessage
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq '' }
        }

        It 'should use the terminal default color for informational messages' {
            Mock Write-Host {}
            Write-ConsoleMessage 'status' -Intent Info
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq 'status' -and -not $ForegroundColor
            }
        }

        It 'should route -Intent Warning to the warning stream, not Write-Host' {
            Mock Write-Host {}
            Write-ConsoleMessage 'careful' -Intent Warning -WarningVariable warnings -WarningAction SilentlyContinue
            ( $warnings -join ' ' ) | Should -Match 'careful'
            Should -Invoke Write-Host -Times 0
        }

        It 'should throw when -NoNewline is combined with -Intent Warning' {
            { Write-ConsoleMessage 'x' -Intent Warning -NoNewline } | Should -Throw '*NoNewline*Warning*'
        }

        It 'should wrap the message in banner markers for -Intent Header' {
            Mock Write-Host {}
            Write-ConsoleMessage 'Section' -Intent Header
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq '=== Section ===' -and $ForegroundColor -eq 'Cyan'
            }
        }

        It 'should render primary and child headings through the layout parameters' {
            Mock Write-Host {}

            Write-ConsoleMessage 'Primary' -Layout Heading
            Write-ConsoleMessage 'Child' -Layout Heading -Child

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq '=== Primary ===' -and $ForegroundColor -eq 'Cyan'
            }
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq 'Child' -and $ForegroundColor -eq 'DarkCyan'
            }
        }

        It 'should render child actions as indented detail' {
            Mock Write-Host {}

            Write-ConsoleMessage 'Stopping PostgreSQL' -Intent Action -Child

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq '  Stopping PostgreSQL' -and $ForegroundColor -eq 'Gray'
            }
        }

        It 'should render usage and child usage with their established indentation' {
            Mock Write-Host {}

            Write-ConsoleMessage '.\\docker.ps1 -Up' -Layout Usage
            Write-ConsoleMessage '1. Start infrastructure' -Layout Usage -Child

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq '  .\\docker.ps1 -Up' -and -not $ForegroundColor
            }
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq '    1. Start infrastructure' -and -not $ForegroundColor
            }
        }

        It 'should format labeled key-value and route layouts' {
            Mock Write-Host {}

            Write-ConsoleMessage 'http://localhost:8080' -Layout KeyValue -Label 'case'
            Write-ConsoleMessage 'Case service' -Layout Route -Label '/api/case/*'

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -match '^  case:.*http://localhost:8080$' -and $ForegroundColor -eq 'Gray'
            }
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -match '^    /api/case/\*.*-> Case service$' -and $ForegroundColor -eq 'DarkGray'
            }
        }

        It 'should require -Label for structured layouts' {
            { Write-ConsoleMessage 'value' -Layout KeyValue } |
                Should -Throw '*-Label is required*KeyValue*'
            { Write-ConsoleMessage 'value' -Layout Route } |
                Should -Throw '*-Label is required*Route*'
        }

        It 'should require -Label for -Intent Endpoint' {
            { Write-ConsoleMessage 'value' -Intent Endpoint } | Should -Throw '*-Label is required*Endpoint*'
        }

        It 'should format -Intent Endpoint with the label prefix' {
            Mock Write-Host {}
            Write-ConsoleMessage 'http://localhost:8080' -Intent Endpoint -Label 'case'
            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -match 'case:.*http://localhost:8080' }
        }

        It 'should require -Label for -Intent Route' {
            { Write-ConsoleMessage 'target' -Intent Route } | Should -Throw '*-Label is required*Route*'
        }

        It 'should preserve compound compatibility intents' -TestCases @(
            @{ Intent = 'Default'; Expected = 'message'; Color = $null }
            @{ Intent = 'SubHeader'; Expected = 'message'; Color = 'DarkCyan' }
            @{ Intent = 'ActionDetail'; Expected = '  message'; Color = 'Gray' }
            @{ Intent = 'Detail'; Expected = '  message'; Color = 'Gray' }
            @{ Intent = 'MutedDetail'; Expected = '    message'; Color = 'DarkGray' }
            @{ Intent = 'Usage'; Expected = '  message'; Color = $null }
            @{ Intent = 'UsageStep'; Expected = '    message'; Color = $null }
        ) {
            param($Intent, $Expected, $Color)

            Mock Write-Host {}
            Write-ConsoleMessage 'message' -Intent $Intent

            Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                $Object -eq $Expected -and $ForegroundColor -eq $Color
            }
        }
    }
}
