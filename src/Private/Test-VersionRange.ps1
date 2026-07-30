<#
.SYNOPSIS
Tests a version against a NuGet version range.

.DESCRIPTION
Follows PSResourceGet's reading of the notation rather than NuGet's own, which differ on one point: a
bare version is the required version, not a minimum-inclusive floor. Bracket a bound to get a range.

Supported forms, matching what Install-PSResource accepts:

    1.2.3        exact
    [1.2.3]      exact
    [1.2.3,]     >= 1.2.3
    (1.2.3,)     >  1.2.3
    [,1.2.3]     <= 1.2.3
    (,1.2.3)     <  1.2.3
    [1.0,2.0]    >= 1.0 and <= 2.0
    (1.0,2.0)    >  1.0 and <  2.0
    [1.0,2.0)    >= 1.0 and <  2.0

An empty or absent range accepts any version.

Two deliberate limits, because this only ever sees versions from Get-Module -ListAvailable, which
reports no prerelease information at all. A range carrying a prerelease suffix returns false rather
than guessing, and so does an unparseable bound - never an exception, since the caller treats false as
"install it" and a throw would break a check that is meant to be cheap. Numeric bounds are compared
with the missing segments filled to zero, so 1.0, 1.0.0, and 1.0.0.0 are one version, as NuGet has it.

.PARAMETER Version
The version to test.

.PARAMETER Range
The range to test against.

.OUTPUTS
System.Boolean

.EXAMPLE
Test-VersionRange -Version ([Version]'5.9.0') -Range '[5.7.1,5.999.999]'

.LINK
https://learn.microsoft.com/nuget/concepts/package-versioning#version-ranges

.NOTES
N/A
#>
function Test-VersionRange {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory)]
        [Version]$Version,

        [String]$Range
    )

    $result = $false

    # Fills absent segments with zero so 1.0, 1.0.0, and 1.0.0.0 compare equal. Returns $null for
    # anything it cannot read, including a prerelease suffix, which [Version] rejects outright.
    $normalize = {
        param([String]$Text)

        $parsed = [Version]::new(0, 0)
        if ([Version]::TryParse($Text, [ref]$parsed)) {
            [Version]::new(
                [Math]::Max($parsed.Major, 0),
                [Math]::Max($parsed.Minor, 0),
                [Math]::Max($parsed.Build, 0),
                [Math]::Max($parsed.Revision, 0)
            )
        }
    }

    $candidate = & $normalize $Version.ToString()

    if ([String]::IsNullOrWhiteSpace($Range)) {
        $result = $true
    }
    elseif ($Range -notmatch '[\[\](),]') {
        # Bare version: the required version, per PSResourceGet.
        $required = & $normalize $Range.Trim()
        $result = $null -ne $required -and $candidate -eq $required
    }
    else {
        $interval = $Range.Trim()
        $minimumInclusive = $interval.StartsWith('[')
        $maximumInclusive = $interval.EndsWith(']')
        $bounds = $interval.Trim('[', ']', '(', ')').Split(',')

        if ($bounds.Count -eq 1) {
            # '[1.2.3]' - a bracketed single value is exact.
            $required = & $normalize $bounds[0].Trim()
            $result = $null -ne $required -and $candidate -eq $required
        }
        else {
            $minimumText = $bounds[0].Trim()
            $maximumText = $bounds[1].Trim()
            $minimum = if ($minimumText) { & $normalize $minimumText }
            $maximum = if ($maximumText) { & $normalize $maximumText }
            $unreadable = ($minimumText -and -not $minimum) -or ($maximumText -and -not $maximum)

            if (-not $unreadable) {
                $result = $true

                if ($minimum) {
                    $result = if ($minimumInclusive) {
                        $candidate -ge $minimum
                    }
                    else {
                        $candidate -gt $minimum
                    }
                }

                if ($result -and $maximum) {
                    $result = if ($maximumInclusive) {
                        $candidate -le $maximum
                    }
                    else {
                        $candidate -lt $maximum
                    }
                }
            }
        }
    }

    return $result
}
