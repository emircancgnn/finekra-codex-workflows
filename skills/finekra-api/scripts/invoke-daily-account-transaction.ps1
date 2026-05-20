param(
    [Parameter(Mandatory = $true)][int]$BankId,
    [Parameter(Mandatory = $true)][string]$TenantId,
    [Parameter(Mandatory = $true)][string]$StartDate,
    [string]$EndDate,
    [switch]$Execute,

    [string]$DailyAccountTransactionUrl = "http://172.16.220.52:8080/api/DailyAccountTransaction",

    [string]$SshHost = "172.16.220.58",
    [string]$SshUser = "emircancagin",
    [string]$SshPassword,

    [int]$DelaySeconds = 3,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

function Convert-ToLocalDate {
    param([string]$Value)
    $culture = [Globalization.CultureInfo]::GetCultureInfo("tr-TR")
    $formats = @("yyyy-MM-dd", "dd.MM.yyyy", "d.M.yyyy", "yyyy-MM-ddTHH:mm:ss", "yyyy-MM-dd HH:mm:ss")
    foreach ($format in $formats) {
        try { return [DateTime]::ParseExact($Value, $format, $culture).Date } catch {}
    }
    return [DateTime]::Parse($Value, $culture).Date
}

function New-DayList {
    param(
        [DateTime]$Start,
        [DateTime]$End
    )
    if ($End -lt $Start) {
        throw "EndDate must be greater than or equal to StartDate."
    }
    $days = New-Object System.Collections.Generic.List[object]
    $cursor = $Start.Date
    while ($cursor -le $End.Date) {
        $days.Add($cursor)
        $cursor = $cursor.AddDays(1)
    }
    return $days
}

function Get-RequiredSecret {
    param(
        [string]$Value,
        [string]$EnvName,
        [string]$Prompt
    )
    if ($Value) { return $Value }
    if ([Environment]::GetEnvironmentVariable($EnvName)) {
        return [Environment]::GetEnvironmentVariable($EnvName)
    }
    $secure = Read-Host $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$start = Convert-ToLocalDate -Value $StartDate
if ($EndDate) {
    $end = Convert-ToLocalDate -Value $EndDate
} else {
    $end = (Get-Date).Date
}
$days = New-DayList -Start $start -End $end

$previewRequests = @($days | ForEach-Object {
    [pscustomobject]@{
        method = "POST"
        url = $DailyAccountTransactionUrl
        body = [ordered]@{
            BankId = $BankId
            TenantId = $TenantId
            Date = $_.ToString("yyyy-MM-dd")
        }
    }
})

if (-not $Execute) {
    [pscustomobject]@{
        mode = "preview"
        message = "No request was sent. Re-run with -Execute to call DailyAccountTransaction."
        requestCount = $previewRequests.Count
        requests = $previewRequests
    } | ConvertTo-Json -Depth 10
    exit 0
}

$SshPassword = Get-RequiredSecret -Value $SshPassword -EnvName "FINEKRA_SSH_58_PASSWORD" -Prompt "Server 58 SSH password"

$payload = [ordered]@{
    dailyAccountTransactionUrl = $DailyAccountTransactionUrl
    delaySeconds = $DelaySeconds
    timeoutSeconds = $TimeoutSeconds
    requests = @($previewRequests | ForEach-Object { $_.body })
}
$payloadJson = $payload | ConvertTo-Json -Depth 20 -Compress
$payload64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($payloadJson))

$remoteScript = @"
`$ErrorActionPreference = 'Stop'
`$payload = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$payload64')) | ConvertFrom-Json

`$headers = @{
    'Content-Type' = 'application/json'
    Accept = 'application/json'
}

`$results = @()
`$index = 0
foreach (`$req in `$payload.requests) {
    `$index++
    `$body = @{
        BankId = `$req.BankId
        TenantId = `$req.TenantId
        Date = `$req.Date
    } | ConvertTo-Json -Compress
    `$startedAt = Get-Date
    try {
        `$response = Invoke-RestMethod -Method Post -Uri `$payload.dailyAccountTransactionUrl -Headers `$headers -ContentType 'application/json' -Body `$body -TimeoutSec `$payload.timeoutSeconds
        `$results += [ordered]@{
            ok = `$true
            bankId = `$req.BankId
            tenantId = `$req.TenantId
            date = `$req.Date
            durationSeconds = [Math]::Round(((Get-Date) - `$startedAt).TotalSeconds, 3)
            response = `$response
        }
    } catch {
        `$statusCode = `$null
        if (`$_.Exception.Response -and `$_.Exception.Response.StatusCode) {
            `$statusCode = [int]`$_.Exception.Response.StatusCode
        }
        `$results += [ordered]@{
            ok = `$false
            bankId = `$req.BankId
            tenantId = `$req.TenantId
            date = `$req.Date
            durationSeconds = [Math]::Round(((Get-Date) - `$startedAt).TotalSeconds, 3)
            statusCode = `$statusCode
            error = `$_.Exception.Message
        }
    }
    if (`$payload.delaySeconds -gt 0 -and `$index -lt `$payload.requests.Count) {
        Start-Sleep -Seconds `$payload.delaySeconds
    }
}

[ordered]@{
    remoteHost = `$env:COMPUTERNAME
    requestCount = `$payload.requests.Count
    results = `$results
} | ConvertTo-Json -Depth 30
"@

Import-Module Posh-SSH
$securePassword = ConvertTo-SecureString $SshPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($SshUser, $securePassword)
$session = New-SSHSession -ComputerName $SshHost -Credential $credential -AcceptKey -ConnectionTimeout 20
$sftp = New-SFTPSession -ComputerName $SshHost -Credential $credential -AcceptKey -ConnectionTimeout 20

try {
    $scriptName = "codex-daily-account-transaction-$([Guid]::NewGuid().ToString('N')).ps1"
    $localScript = Join-Path $env:TEMP $scriptName
    $remoteTemp = "C:\Users\$SshUser\AppData\Local\Temp"
    $remoteSftpTemp = "/C:/Users/$SshUser/AppData/Local/Temp"
    $remoteScriptPath = "$remoteTemp\$scriptName"
    Set-Content -LiteralPath $localScript -Value $remoteScript -Encoding UTF8
    Set-SFTPItem -SessionId $sftp.SessionId -Path $localScript -Destination $remoteSftpTemp -Force | Out-Null

    $escapedRemoteScriptPath = $remoteScriptPath.Replace('"', '\"')
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "powershell -NoProfile -ExecutionPolicy Bypass -File `"$escapedRemoteScriptPath`"" -TimeOut ([Math]::Max($TimeoutSeconds * ($days.Count + 1), 120))
    $remoteScriptPathForSingleQuoted = $remoteScriptPath.Replace("'", "''")
    Invoke-SSHCommand -SessionId $session.SessionId -Command "powershell -NoProfile -Command `"Remove-Item -LiteralPath '$remoteScriptPathForSingleQuoted' -Force -ErrorAction SilentlyContinue`"" -TimeOut 20 | Out-Null
    Remove-Item -LiteralPath $localScript -Force -ErrorAction SilentlyContinue
    if ($result.Error) {
        Write-Error ($result.Error -join [Environment]::NewLine)
    }
    $result.Output
}
finally {
    if ($sftp) { Remove-SFTPSession -SessionId $sftp.SessionId | Out-Null }
    if ($session) { Remove-SSHSession -SessionId $session.SessionId | Out-Null }
}
