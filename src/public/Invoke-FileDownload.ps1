#
.SYNOPSIS
Downloads a remote file, optionally using credentials.
.DESCRIPTION
Downloads a remote file, optionally using credentials. It includes retry logic for large file downloads or unstable
connections.
.PARAMETER Source
Url of the file to download.
.PARAMETER Destination
Directory to download the file to.
.PARAMETER FileName
Name of the downloaded file. Tries to determine the file name from the Source URL if not specified.
.PARAMETER Credential
PSCredential object with credentials authorized to download the file.
.PARAMETER Username
Username authorized to download the file.
.PARAMETER PlainTextPass
Password of the user authorized to download the file.
.PARAMETER MaximumRetries
Maximum number of times to delay and retry the download when it's interrupted.
.PARAMETER ProgressUpdateInterval
Interval in seconds to update download progress. Defaults to 1. Set to 0 for no updates.
.EXAMPLE
$source = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi'
Invoke-FileDownload $source
.NOTES
N/A
#>
function Invoke-FileDownload {
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String[]]
        $Source,
        [String]
        $Destination = "$env:USERPROFILE/Downloads",
        [String]
        $FileName,
        [Parameter(ParameterSetName = 'Credential')]
        [PSCredential]
        $Credential,
        [Parameter(ParameterSetName = 'Username', Mandatory = $true)]
        [String]
        $Username,
        [Parameter(ParameterSetName = 'Username', Mandatory = $true)]
        [String]
        $PlainTextPass,
        [Int]
        $MaximumRetries = 3,
        [Int]
        $ProgressUpdateInterval = 1
    )


    <#
    .DESCRIPTION
    Generates a sequence of fibonacci numbers to use for delays.
    #>
    function Get-FibonacciNumbers {
        param ([int]$n)
        if ($n -le 0) { return $n }
        $fibonacci = @(1)
        if ($n -ge 2) { $fibonacci += 2 }
        for ($i = 2; $i -lt $n; $i++) {
            $fibonacci += ($fibonacci[$i - 1] + $fibonacci[$i - 2])
        }
        return $fibonacci
    }
    <#
    .DESCRIPTION
    Opens a web request and resumes from a specified range.
    #>
    function New-HttpWebRequest {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, Position = 0)]
            [String]$Uri,
            [PSCredential]$Credential,
            [Int64]$CurrentRange
        )
        $connectionVerb = if ($CurrentRange) { 'Resuming' } else { 'Initializing' }
        Write-Host "$connectionVerb web request: $Uri..."
        $script:webRequest = [System.Net.HttpWebRequest]::Create($Uri)
        if ($Credential) {
            $script:webRequest.Credentials = $Credential.GetNetworkCredential()
            $script:webRequest.PreAuthenticate = $true
        }
        $script:webRequest.Method = 'GET'
        if ($CurrentRange) {
            $script:webRequest.AddRange($CurrentRange)
        }
        try {
            $script:response = $script:webRequest.GetResponse()
            $script:responseStream = $script:response.GetResponseStream()
        }
        catch {
            # Failing .net methods don't exit the script so an explicit throw is needed
            throw $_
        }
    }


    $retryDelaySeconds = @( Get-FibonacciNumbers -n $MaximumRetries )
    if ($Username) {
        $securePass = ConvertTo-SecureString $PlainTextPass -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($Username, $securePass)
    }
    foreach ($uri in $Source) {
        New-HttpWebRequest -Uri $uri -Credential $Credential
        if (-not $FileName) {
            Write-Host 'Getting file information...'
            $contentDisposition = $script:response.Headers['Content-Disposition']
            if ($contentDisposition -and $contentDisposition -match 'filename="(.+)"') {
                $FileName = $Matches[1]
            }
            else {
                $FileName = [System.IO.Path]::GetFileName($uri)
                if (-not [System.IO.Path]::HasExtension($FileName)) {
                    # Generate a filename from the whole URI
                    $FileName = $uri -replace ('https?://', '') -replace ('[^a-zA-Z0-9\.\-_]', '_')
                }
            }
        }
        $baseUri = [System.Uri]::new($uri).GetLeftPart([System.UriPartial]::Authority)
        $tempDirectoryName = $baseUri -replace ('https?://', '') -replace ('[^a-zA-Z0-9\.\-_]', '_')
        $tempFilePath = Join-Path `
            -Path ( Join-Path -Path $env:TEMP -ChildPath $tempDirectoryName ) `
            -ChildPath ( New-Guid ).Guid
        $tempFile = New-Item -Path $tempFilePath -ItemType File -Force
        Write-Host "Downloading $FileName from $uri..."
        $progress = @{
            Activity = $FileName
            Status   = 'Downloading...'
        }
        Write-Progress @progress

        $fileStream = [System.IO.File]::Create($tempFile.FullName)
        $bufferSize = 8192
        $buffer = New-Object byte[] $bufferSize
        $totalBytesRead = 0
        $totalBytes = $script:response.ContentLength
        $totalMB = [Math]::Round($totalBytes / 1MB, 2)
        $startTime = Get-Date
        $lastProgressUpdate = $startTime
        $readAttempt = 0
        do {
            try {
                $bytesRead = $script:responseStream.Read($buffer, 0, $bufferSize)
                if ($bytesRead -le 0) {
                    break
                }
                $fileStream.Write($buffer, 0, $bytesRead)
                $totalBytesRead += $bytesRead
                # Update progress at most once per value in $ProgressUpdateInterval or on the last loop iteration
                $currentTime = Get-Date
                $updateProgress = (
                    $ProgressUpdateInterval -gt 0 -and
                    (
                        $bytesRead -le 0 -or
                        ($currentTime - $lastProgressUpdate).TotalSeconds -ge $ProgressUpdateInterval
                    )
                )
                if ($updateProgress) {
                    $totalMBRead = [Math]::Round($totalBytesRead / 1MB, 2)
                    if ($totalBytes -gt 0) {
                        $progress['CurrentOperation'] = "$totalMBRead/$totalMB MB"
                        $progress['PercentComplete'] = (($totalBytesRead / $totalBytes) * 100)
                    }
                    else {
                        $progress['CurrentOperation'] = "$totalMBRead MB"
                    }
                    Write-Progress @progress
                    $lastProgressUpdate = $currentTime
                }
            }
            catch {
                Write-Host "Download attempt $($readAttempt + 1) failed."
                Write-Host $_.Exception.Message
                if ($readAttempt -lt $MaximumRetries) {
                    $retryDelay = $retryDelaySeconds[$readAttempt]
                    $readAttempt++
                    Write-Host "Waiting $retryDelay seconds before reconnecting and resuming..."
                    $progress['CurrentOperation'] = "Waiting $retryDelay seconds..."
                    Write-Progress @progress
                    Start-Sleep -Seconds $retryDelay
                    # Re-open connection on retry at current read position
                    $fileSize = $tempFile.FullName | Get-Item | Select-Object -ExpandProperty Length
                    if ( Compare-Object -ReferenceObject $fileSize -DifferenceObject $totalBytesRead ) {
                        Write-Warning 'The in-progress file size does not match the expected size. Restarting download...'
                        $totalBytesRead = 0
                        $fileStream.Close()
                        $tempFile | Remove-Item -Force -ErrorAction SilentlyContinue
                        $tempFile = New-Item -Path $tempFilePath -ItemType File -Force
                        $fileStream = [System.IO.File]::Create($tempFile.FullName)
                    }
                    New-HttpWebRequest -Uri $uri -Credential $Credential -CurrentRange $totalBytesRead
                    continue
                }
                else {
                    $fileStream.Close()
                    $script:responseStream.Close()
                    Write-Progress @progress -Completed
                    throw $_
                }
            }
        }
        while ($true)

        $fileStream.Close()
        $script:responseStream.Close()
        $endTime = Get-Date
        $totalTimeElapsed = ($endTime - $startTime)
        Write-Progress @progress -Completed
        Write-Host "$FileName download complete. Time elapsed: $($totalTimeElapsed.ToString('hh\:mm\:ss'))"
        Copy-Item -Path $tempFile.FullName -Destination "$Destination/$FileName" -Force -PassThru
        $tempFile | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}