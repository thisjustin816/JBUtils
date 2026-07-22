<#
.SYNOPSIS
Shows available colors that can be used in the console.

.DESCRIPTION
Shows available colors that can be used in the console and examples of what they will look like.

.EXAMPLE
Show-ConsoleColor

Lists available colors and shows what the color will look like in the current console.

.NOTES
N/A
#>

function Show-ConsoleColor {
    [CmdletBinding()]
    param()
    Write-Host -Object ('{0,-120}' -f ' ') -ForegroundColor Black -BackgroundColor White
    foreach ($heading in 'Color', 'Foreground', 'Background') {
        Write-Host -Object ('{0,-40}' -f $heading) -ForegroundColor Black -BackgroundColor White -NoNewline
    }
    Write-Host
    $colors = [enum]::GetValues([System.ConsoleColor])
    foreach ($color in $colors) {
        $object = @{ Object = ('{0,-40}' -f $color) }
        Write-Host @object -NoNewline
        Write-Host @object -ForegroundColor $color -NoNewline
        Write-Host @object -ForegroundColor $colors[$colors.Count - $color - 1] -BackgroundColor $color
    }
}
