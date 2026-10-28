<#
.SYNOPSIS
Internal: Uses Git Credential Manager with a native OS store and an isolated credential namespace.
#>
function Invoke-OsCredentialStore {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'The redirected OS-store protocol supplies plaintext; only a credential object is returned.'
    )]
    [CmdletBinding()]
    [OutputType([PSCredential])]
    param(
        [ValidateSet('get', 'store', 'erase')]
        [String]$Operation,
        [String]$Name,
        [String]$UserName,
        [String]$Namespace,
        [PSCredential]$Credential
    )

    if ($Credential) {
        $UserName = $Credential.UserName
    }
    if (-not $UserName -or $UserName -match '[\r\n\x00]') {
        throw 'The credential account must be a nonempty single line.'
    }
    $store = if ($PSVersionTable['Platform'] -eq 'Unix') {
        if ($IsMacOS) { 'keychain' } else { 'secretservice' }
    }
    else {
        'wincredman'
    }
    $git = @(Get-Command -Name git -CommandType Application -ErrorAction Stop)[0]
    $start = [Diagnostics.ProcessStartInfo]::new($git.Source, "credential-manager $Operation")
    $start.WorkingDirectory = if ($PSVersionTable['Platform'] -eq 'Unix') {
        '/'
    }
    else {
        [Environment]::SystemDirectory
    }
    foreach ($key in @($start.EnvironmentVariables.Keys)) {
        if ($key -match '^GCM_|^GIT_TRACE|^GIT_CONFIG|^GIT_(DIR|WORK_TREE|COMMON_DIR)$') {
            $start.EnvironmentVariables.Remove($key)
        }
    }
    $settings = @{
        GCM_CREDENTIAL_STORE  = $store
        GCM_NAMESPACE         = $Namespace
        GCM_PROVIDER          = 'generic'
        GCM_INTERACTIVE       = 'never'
        GCM_GUI_PROMPT        = 'false'
        GCM_ALLOW_WINDOWSAUTH = 'false'
        GCM_TRACE             = '0'
        GIT_CONFIG_NOSYSTEM   = '1'
        GIT_CONFIG_GLOBAL     = if ($PSVersionTable['Platform'] -eq 'Unix') { '/dev/null' } else { 'NUL' }
        GIT_TERMINAL_PROMPT   = '0'
    }
    foreach ($key in $settings.Keys) {
        $start.EnvironmentVariables[$key] = $settings[$key]
    }
    $inputText = "protocol=jbutils`nhost=localhost`npath=$Name`nusername=$UserName`n"
    try {
        if ($Credential) {
            $password = $Credential.GetNetworkCredential().Password
            if (-not $password -or $password -match '[\r\n\x00]') {
                throw 'The credential password must be a nonempty single line.'
            }
            $inputText += "password=$password`n"
        }
        $inputText += "`n"
        try {
            $response = Invoke-OsCredentialProtocol -StartInfo $start -InputText $inputText
        }
        catch {
            throw 'OS credential store operation failed. Verify Git Credential Manager and an unlocked native store.'
        }
        if ($Operation -eq 'get') {
            $fields = @{}
            foreach ($line in $response -split '\r?\n') {
                if ($line -match '^([^=]+)=(.*)$') {
                    $fields[$Matches[1]] = $Matches[2]
                }
            }
            if ($fields['username'] -cne $UserName -or -not $fields['password']) {
                throw 'OS credential store did not return a usable credential for the requested account.'
            }
            [PSCredential]::new($UserName, (ConvertTo-SecureString $fields['password'] -AsPlainText -Force))
        }
    }
    finally {
        $inputText = $null
        $password = $null
        $response = $null
        $fields = $null
    }
}
