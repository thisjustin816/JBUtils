<#
.SYNOPSIS
Serializes an object to PowerShell data-file (.psd1) literal syntax.

.DESCRIPTION
Recursively renders strings, numbers, booleans, arrays, and dictionaries as PowerShell data-file
literal text, suitable for writing a hand-editable .psd1 file. Unsupported types are rendered as
their quoted string representation.

.PARAMETER InputObject
The object to serialize. Accepts pipeline input.

.PARAMETER Indent
The current indentation level, in 4-space increments. Used internally for recursive calls; callers
normally omit it.

.OUTPUTS
System.String

.EXAMPLE
ConvertTo-Psd1 -InputObject @{ Name = 'MyModule'; Tags = @('PSEdition_Core') }

.NOTES
N/A
#>
function ConvertTo-Psd1 {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        $InputObject,

        [Int]$Indent = 0
    )

    process {
        $indentText = ' ' * ($Indent * 4)
        $childPad = ' ' * (($Indent + 1) * 4)

        if ($null -eq $InputObject) {
            '$null'
        }
        elseif ($InputObject -is [Bool]) {
            if ($InputObject) {
                '$true'
            }
            else {
                '$false'
            }
        }
        elseif ($InputObject -is [Int] -or $InputObject -is [Long] -or
            $InputObject -is [Double] -or $InputObject -is [Decimal]) {
            "$InputObject"
        }
        elseif ($InputObject -is [System.Collections.IDictionary]) {
            if ($InputObject.Count -eq 0) {
                '@{}'
            }
            else {
                $keyWidth = ($InputObject.Keys | ForEach-Object -Process { "$_".Length } |
                        Measure-Object -Maximum).Maximum
                $lines = [System.Collections.Generic.List[String]]::new()
                $lines.Add('@{')
                foreach ($key in $InputObject.Keys) {
                    # The recursive call already carries absolute indentation, so the opening
                    # token goes inline after "key =" and continuation lines are added as-is.
                    $rendered = ConvertTo-Psd1 -InputObject $InputObject[$key] -Indent ($Indent + 1)
                    $lines.Add("$childPad$("$key".PadRight($keyWidth)) = $rendered")
                }
                $lines.Add("$indentText}")
                $lines -join "`n"
            }
        }
        elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [String]) {
            $items = @($InputObject)
            if ($items.Count -eq 0) {
                '@()'
            }
            else {
                $lines = [System.Collections.Generic.List[String]]::new()
                $lines.Add('@(')
                foreach ($item in $items) {
                    $lines.Add("$childPad$(ConvertTo-Psd1 -InputObject $item -Indent ($Indent + 1))")
                }
                $lines.Add("$indentText)")
                $lines -join "`n"
            }
        }
        else {
            "'" + ("$InputObject" -replace "'", "''") + "'"
        }
    }
}
