<#
.SYNOPSIS
Writes a formatted message to the host.

.DESCRIPTION
Two ways to style output: -ForegroundColor for direct color control with no other formatting, or
-Intent for semantic meaning. The intent controls color and output-stream routing, while -Layout
controls presentation and -Child selects the secondary form of that layout or intent. Legacy
compound intents remain available while callers migrate to the separated parameters.

.PARAMETER Message
The message to display.

.PARAMETER ForegroundColor
Writes the message in this color with no other formatting. Mutually exclusive with -Intent.

.PARAMETER Intent
The semantic purpose of the message: Info, Action, Success, Warning, Caution, or Muted. Mutually
exclusive with -ForegroundColor. Legacy compound values remain available for compatibility.

.PARAMETER Layout
The message presentation: Text, Heading, Usage, KeyValue, or Route.

.PARAMETER Child
Uses the child presentation for a heading, action, muted message, or usage line.

.PARAMETER Label
A label prefix, required when -Layout is KeyValue or Route.

.PARAMETER NoNewline
Suppresses the trailing newline. Not supported with -Intent Warning, since warnings use the warning
stream rather than Write-Host.

.EXAMPLE
Write-ConsoleMessage 'Building...' -ForegroundColor Cyan

.EXAMPLE
Write-ConsoleMessage 'Build' -Layout Heading

.EXAMPLE
Write-ConsoleMessage 'Compiling case' -Intent Action -Child

.NOTES
N/A
#>
function Write-ConsoleMessage {
    [CmdletBinding(DefaultParameterSetName = 'Intent')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'The intended purpose of this function is formatted host output.'
    )]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [String]$Message = '',

        [Parameter(ParameterSetName = 'Color')]
        [ConsoleColor]$ForegroundColor,

        [Parameter(ParameterSetName = 'Intent')]
        [ValidateSet(
            # Primary intents
            'Info',
            'Action',
            'Success',
            'Warning',
            'Caution',
            'Muted',
            # Compatibility intents
            'Default',
            'Header',
            'SubHeader',
            'ActionDetail',
            'Detail',
            'Endpoint',
            'MutedDetail',
            'Route',
            'Usage',
            'UsageStep'
        )]
        [String]$Intent = 'Info',

        [Parameter(ParameterSetName = 'Intent')]
        [ValidateSet(
            'Text',
            'Heading',
            'Usage',
            'KeyValue',
            'Route'
        )]
        [String]$Layout = 'Text',

        [Parameter(ParameterSetName = 'Intent')]
        [Switch]$Child,

        [Parameter(ParameterSetName = 'Intent')]
        [String]$Label,

        [Switch]$NoNewline
    )

    if ($PSCmdlet.ParameterSetName -eq 'Color') {
        $writeHostParameters = @{ Object = $Message }
        if ($PSBoundParameters.ContainsKey('ForegroundColor')) {
            $writeHostParameters.ForegroundColor = $ForegroundColor
        }
        if ($NoNewline) {
            $writeHostParameters.NoNewline = $true
        }

        Write-Host @writeHostParameters
        return
    }

    $effectiveIntent = $Intent
    $effectiveLayout = $Layout
    $effectiveChild = $Child.IsPresent

    # Compatibility mappings for the original compound intent vocabulary.
    switch ($Intent) {
        'Default' {
            $effectiveIntent = 'Info'
        }
        'Header' {
            $effectiveIntent = 'Info'
            $effectiveLayout = 'Heading'
        }
        'SubHeader' {
            $effectiveIntent = 'Info'
            $effectiveLayout = 'Heading'
            $effectiveChild = $true
        }
        'ActionDetail' {
            $effectiveIntent = 'Action'
            $effectiveChild = $true
        }
        'Detail' {
            $effectiveIntent = 'Info'
            $effectiveChild = $true
        }
        'Endpoint' {
            $effectiveIntent = 'Info'
            $effectiveLayout = 'KeyValue'
        }
        'MutedDetail' {
            $effectiveIntent = 'Muted'
            $effectiveChild = $true
        }
        'Route' {
            $effectiveIntent = 'Muted'
            $effectiveLayout = 'Route'
        }
        'Usage' {
            $effectiveIntent = 'Info'
            $effectiveLayout = 'Usage'
        }
        'UsageStep' {
            $effectiveIntent = 'Info'
            $effectiveLayout = 'Usage'
            $effectiveChild = $true
        }
    }

    if ($effectiveIntent -eq 'Warning') {
        if ($NoNewline) {
            throw '-NoNewline is not supported with -Intent Warning because warnings use the warning stream.'
        }

        Write-Warning -Message $Message
        return
    }

    $intentColor = switch ($effectiveIntent) {
        'Info' { $null }
        'Action' { 'Cyan' }
        'Success' { 'Green' }
        'Caution' { 'Yellow' }
        'Muted' { 'DarkGray' }
    }

    if ($effectiveLayout -eq 'Heading') {
        $intentColor = if ($effectiveChild) { 'DarkCyan' } else { 'Cyan' }
    }
    elseif ($effectiveLayout -eq 'KeyValue') {
        $intentColor = 'Gray'
    }
    elseif ($effectiveLayout -eq 'Route') {
        $intentColor = 'DarkGray'
    }
    elseif (
        $effectiveLayout -eq 'Text' -and
        $effectiveChild -and
        $effectiveIntent -in @('Info', 'Action')
    ) {
        $intentColor = 'Gray'
    }

    if ($effectiveLayout -in @('KeyValue', 'Route') -and -not $Label) {
        $labelContext = if ($Intent -in @('Endpoint', 'Route')) {
            $Intent
        }
        else {
            $effectiveLayout
        }
        throw "-Label is required when using $labelContext."
    }

    if ($effectiveLayout -eq 'Heading' -and -not $effectiveChild) {
        Write-ConsoleMessage
        $Message = "=== $Message ==="
    }
    elseif (
        $effectiveIntent -eq 'Success' -and
        $effectiveLayout -eq 'Text' -and
        -not $effectiveChild -and
        -not $NoNewline
    ) {
        Write-ConsoleMessage
    }
    elseif ($effectiveLayout -eq 'Usage') {
        $indent = if ($effectiveChild) { '    ' } else { '  ' }
        $Message = "$indent$Message"
    }
    elseif ($effectiveLayout -eq 'KeyValue') {
        $Message = '  {0,-19}{1}' -f ('{0}:' -f $Label), $Message
    }
    elseif ($effectiveLayout -eq 'Route') {
        $Message = '    {0,-15}-> {1}' -f $Label, $Message
    }
    elseif ($effectiveLayout -eq 'Text' -and $effectiveChild) {
        $indent = if ($effectiveIntent -eq 'Muted') { '    ' } else { '  ' }
        $Message = "$indent$Message"
    }

    $writeHostParameters = @{ Object = $Message }
    if ($intentColor) {
        $writeHostParameters.ForegroundColor = $intentColor
    }
    if ($NoNewline) {
        $writeHostParameters.NoNewline = $true
    }

    Write-Host @writeHostParameters
}
