﻿#Requires -Modules PackageManagement, PowerShellGet, Microsoft.PowerShell.PSResourceGet
[CmdletBinding()]
param ()

Get-ChildItem -Path "$PSScriptRoot/public" -Filter '*.ps1' -Exclude '*.Tests.ps1' -File -Recurse |
    ForEach-Object -Process {
        . $_.FullName
    }
