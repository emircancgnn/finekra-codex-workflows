param(
    [string]$SshHost = "172.16.220.58",
    [string]$SshUser = "emircancagin",
    [Parameter(Mandatory = $true)][string]$SshPassword,
    [Parameter(Mandatory = $true)][string]$FinekraEmail,
    [Parameter(Mandatory = $true)][string]$FinekraPassword,
    [Parameter(Mandatory = $true)][string]$TenantCode,
    [string]$BaseUrl = "https://polynom-api.finekra.com/api",
    [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")][string]$Method = "GET",
    [string]$Path,
    [string]$QueryString,
    [string]$BodyJson,
    [switch]$ShowFullToken,
    [switch]$AuthOnly
)

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Import-Module Posh-SSH

$securePassword = ConvertTo-SecureString $SshPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($SshUser, $securePassword)
$session = New-SSHSession -ComputerName $SshHost -Credential $credential -AcceptKey -ConnectionTimeout 20
$sftp = New-SFTPSession -ComputerName $SshHost -Credential $credential -AcceptKey -ConnectionTimeout 20

try {
    $payload = @{
        finekraEmail = $FinekraEmail
        finekraPassword = $FinekraPassword
        tenantCode = $TenantCode
        baseUrl = $BaseUrl.TrimEnd("/")
        method = $Method
        path = $Path
        queryString = $QueryString
        bodyJson = $BodyJson
        showFullToken = [bool]$ShowFullToken
        authOnly = [bool]$AuthOnly
    } | ConvertTo-Json -Compress

    $payload64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payload))

    $remoteScript = @"
`$payload = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$payload64')) | ConvertFrom-Json
`$baseUrl = `$payload.baseUrl.TrimEnd('/')
`$authUrl = "`$baseUrl/Auth/DealerLogin"
`$authBodyObject = @{
    email = `$payload.finekraEmail
    password = `$payload.finekraPassword
    tenantCode = `$payload.tenantCode
    screenOption = 0
}
`$authBody = `$authBodyObject | ConvertTo-Json -Compress
`$authHeaders = @{ 'Content-Type' = 'application/json'; 'Accept' = 'application/json' }

`$authResult = Invoke-WebRequest -Method Post -Uri `$authUrl -Headers `$authHeaders -ContentType 'application/json' -Body `$authBody -UseBasicParsing
`$authJson = `$authResult.Content | ConvertFrom-Json
`$token = `$authJson.data.token
`$tokenDisplay = if (`$payload.showFullToken) { `$token } elseif (`$token) { `$token.Substring(0, [Math]::Min(12, `$token.Length)) + '...' + `$token.Substring([Math]::Max(0, `$token.Length - 8)) } else { `$null }

`$output = [ordered]@{
    remoteHost = `$env:COMPUTERNAME
    auth = [ordered]@{
        request = [ordered]@{
            method = 'POST'
            url = `$authUrl
            headers = `$authHeaders
            body = [ordered]@{
                email = `$payload.finekraEmail
                password = if (`$payload.showFullToken) { `$payload.finekraPassword } else { '<redacted>' }
                tenantCode = `$payload.tenantCode
                screenOption = 0
            }
        }
        response = [ordered]@{
            statusCode = [int]`$authResult.StatusCode
            statusDescription = `$authResult.StatusDescription
            body = [ordered]@{
                success = `$authJson.success
                message = `$authJson.message
                statusCode = `$authJson.statusCode
                expiration = `$authJson.data.expiration
                token = `$tokenDisplay
            }
        }
    }
}

if (-not `$payload.authOnly -and `$payload.path) {
    `$path = [string]`$payload.path
    if (-not `$path.StartsWith('/')) { `$path = '/' + `$path }
    `$url = "`$baseUrl`$path"
    if (`$payload.queryString) {
        `$qs = [string]`$payload.queryString
        if (`$qs.StartsWith('?')) { `$url = "`$url`$qs" } else { `$url = "`$url?`$qs" }
    }
    `$headers = @{ 'Authorization' = "Bearer `$token"; 'Content-Type' = 'application/json'; 'Accept' = 'application/json' }
    `$requestArgs = @{
        Method = `$payload.method
        Uri = `$url
        Headers = `$headers
        UseBasicParsing = `$true
    }
    if (`$payload.bodyJson) {
        `$requestArgs['ContentType'] = 'application/json'
        `$requestArgs['Body'] = [string]`$payload.bodyJson
    }
    `$apiResult = Invoke-WebRequest @requestArgs
    `$apiBody = try { `$apiResult.Content | ConvertFrom-Json } catch { `$apiResult.Content }
    `$headersForDisplay = [ordered]@{
        Authorization = if (`$payload.showFullToken) { "Bearer `$token" } else { 'Bearer <redacted>' }
        'Content-Type' = 'application/json'
        Accept = 'application/json'
    }
    `$output['api'] = [ordered]@{
        request = [ordered]@{
            method = `$payload.method
            url = `$url
            headers = `$headersForDisplay
            body = if (`$payload.bodyJson) { try { `$payload.bodyJson | ConvertFrom-Json } catch { `$payload.bodyJson } } else { `$null }
        }
        response = [ordered]@{
            statusCode = [int]`$apiResult.StatusCode
            statusDescription = `$apiResult.StatusDescription
            headers = `$apiResult.Headers
            body = `$apiBody
        }
    }
}

`$output | ConvertTo-Json -Depth 30
"@

    $scriptName = "codex-finekra-$([Guid]::NewGuid().ToString('N')).ps1"
    $localScript = Join-Path $env:TEMP $scriptName
    $remoteTemp = "C:\Users\$SshUser\AppData\Local\Temp"
    $remoteSftpTemp = "/C:/Users/$SshUser/AppData/Local/Temp"
    $remoteScriptPath = "$remoteTemp\$scriptName"
    Set-Content -LiteralPath $localScript -Value $remoteScript -Encoding UTF8
    Set-SFTPItem -SessionId $sftp.SessionId -Path $localScript -Destination $remoteSftpTemp -Force | Out-Null

    $escapedRemoteScriptPath = $remoteScriptPath.Replace('"', '\"')
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "powershell -NoProfile -ExecutionPolicy Bypass -File `"$escapedRemoteScriptPath`"" -TimeOut 120
    $remoteScriptPathForSingleQuoted = $remoteScriptPath.Replace("'", "''")
    Invoke-SSHCommand -SessionId $session.SessionId -Command "powershell -NoProfile -Command `"Remove-Item -LiteralPath '$remoteScriptPathForSingleQuoted' -Force -ErrorAction SilentlyContinue`"" -TimeOut 20 | Out-Null
    Remove-Item -LiteralPath $localScript -Force -ErrorAction SilentlyContinue
    if ($result.Error) {
        Write-Error ($result.Error -join [Environment]::NewLine)
    }
    $result.Output
}
finally {
    if ($sftp) {
        Remove-SFTPSession -SessionId $sftp.SessionId | Out-Null
    }
    Remove-SSHSession -SessionId $session.SessionId | Out-Null
}
