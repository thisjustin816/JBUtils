$Name = 'JBUtils'

Import-Module -Name "$PSScriptRoot/out/$Name" -Force -ErrorAction Stop
Publish-PSModule -Name $Name -Confirm:(-not $env:GITHUB_ACTIONS)
