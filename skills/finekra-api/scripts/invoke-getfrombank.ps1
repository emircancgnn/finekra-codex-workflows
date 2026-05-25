param(
    [Parameter(Mandatory = $true)][string]$BankInfoId,
    [Parameter(Mandatory = $true)][string]$StartDate,
    [Parameter(Mandatory = $true)][string]$EndDate,
    [switch]$Daily,
    [switch]$Execute,

    [string]$GetFromBankUrl = "http://172.16.220.53:8080/api/Transaction/GetFromBank",

    [string]$SshHost = "172.16.220.58",
    [string]$SshUser = "emircancagin",
    [string]$SshPassword,

    [int]$DelaySeconds = 3,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

function Convert-ToIsoLocalDateTime {
    param(
        [string]$Value,
        [bool]$EndOfDay
    )
    $culture = [Globalization.CultureInfo]::GetCultureInfo("tr-TR")
    $formats = @(
        "yyyy-MM-ddTHH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "dd.MM.yyyy HH:mm:ss",
        "dd.MM.yyyy",
        "d.M.yyyy HH:mm:ss",
        "d.M.yyyy"
    )
    $parsed = $null
    foreach ($format in $formats) {
        try {
            $parsed = [DateTime]::ParseExact($Value, $format, $culture)
            break
        } catch {}
    }
    if (-not $parsed) {
        $parsed = [DateTime]::Parse($Value, $culture)
    }
    if ($Value -notmatch "T|\d{1,2}:\d{2}") {
        if ($EndOfDay) {
            $parsed = $parsed.Date.AddDays(1).AddSeconds(-1)
        } else {
            $parsed = $parsed.Date
        }
    }
    return $parsed.ToString("yyyy-MM-ddTHH:mm:ss")
}

function New-DateRanges {
    param(
        [DateTime]$Start,
        [DateTime]$End,
        [bool]$SplitDaily
    )
    if ($End -lt $Start) {
        throw "EndDate must be greater than or equal to StartDate."
    }
    if (-not $SplitDaily) {
        return @([pscustomobject]@{ Start = $Start; End = $End })
    }

    $ranges = New-Object System.Collections.Generic.List[object]
    $cursor = $Start
    while ($cursor -le $End) {
        $dayEnd = $cursor.Date.AddDays(1).AddSeconds(-1)
        if ($dayEnd -gt $End) { $dayEnd = $End }
        $ranges.Add([pscustomobject]@{ Start = $cursor; End = $dayEnd })
        $cursor = $dayEnd.AddSeconds(1)
    }
    return $ranges
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

$startIso = Convert-ToIsoLocalDateTime -Value $StartDate -EndOfDay $false
$endIso = Convert-ToIsoLocalDateTime -Value $EndDate -EndOfDay $true
$start = [DateTime]::ParseExact($startIso, "yyyy-MM-ddTHH:mm:ss", [Globalization.CultureInfo]::InvariantCulture)
$end = [DateTime]::ParseExact($endIso, "yyyy-MM-ddTHH:mm:ss", [Globalization.CultureInfo]::InvariantCulture)
$ranges = New-DateRanges -Start $start -End $end -SplitDaily ([bool]$Daily)

$previewRequests = @($ranges | ForEach-Object {
    [pscustomobject]@{
        method = "POST"
        url = $GetFromBankUrl
        body = [ordered]@{
            startDate = $_.Start.ToString("yyyy-MM-ddTHH:mm:ss")
            endDate = $_.End.ToString("yyyy-MM-ddTHH:mm:ss")
            bankInfoId = $BankInfoId
        }
    }
})

if (-not $Execute) {
    [pscustomobject]@{
        mode = "preview"
        message = "No request was sent. Re-run with -Execute to call GetFromBank."
        requestCount = $previewRequests.Count
        requests = $previewRequests
    } | ConvertTo-Json -Depth 10
    exit 0
}

$SshPassword = Get-RequiredSecret -Value $SshPassword -EnvName "FINEKRA_SSH_58_PASSWORD" -Prompt "Server 58 SSH password"

$payload = [ordered]@{
    getFromBankUrl = $GetFromBankUrl
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
`$total = `$payload.requests.Count
foreach (`$req in `$payload.requests) {
    `$index++
    `$label = "[`$index/`$total] `$(`$req.startDate) - `$(`$req.endDate)"
    Write-Output "START `$label"
    `$body = @{
        startDate = `$req.startDate
        endDate = `$req.endDate
        bankInfoId = `$req.bankInfoId
    } | ConvertTo-Json -Compress
    `$startedAt = Get-Date
    try {
        `$response = Invoke-RestMethod -Method Post -Uri `$payload.getFromBankUrl -Headers `$headers -ContentType 'application/json' -Body `$body -TimeoutSec `$payload.timeoutSeconds
        `$results += [ordered]@{
            ok = `$true
            startDate = `$req.startDate
            endDate = `$req.endDate
            bankInfoId = `$req.bankInfoId
            durationSeconds = [Math]::Round(((Get-Date) - `$startedAt).TotalSeconds, 3)
            response = `$response
        }
        Write-Output "OK    `$label durationSeconds=`$([Math]::Round(((Get-Date) - `$startedAt).TotalSeconds, 3))"
    } catch {
        `$statusCode = `$null
        if (`$_.Exception.Response -and `$_.Exception.Response.StatusCode) {
            `$statusCode = [int]`$_.Exception.Response.StatusCode
        }
        `$results += [ordered]@{
            ok = `$false
            startDate = `$req.startDate
            endDate = `$req.endDate
            bankInfoId = `$req.bankInfoId
            durationSeconds = [Math]::Round(((Get-Date) - `$startedAt).TotalSeconds, 3)
            statusCode = `$statusCode
            error = `$_.Exception.Message
        }
        Write-Output "ERROR `$label statusCode=`$statusCode error=`$(`$_.Exception.Message)"
    }
    if (`$payload.delaySeconds -gt 0 -and `$index -lt `$payload.requests.Count) {
        Write-Output "WAIT  `$payload.delaySeconds seconds"
        Start-Sleep -Seconds `$payload.delaySeconds
    }
}

Write-Output "SUMMARY_JSON_BEGIN"
[ordered]@{
    remoteHost = `$env:COMPUTERNAME
    requestCount = `$payload.requests.Count
    results = `$results
} | ConvertTo-Json -Depth 30
Write-Output "SUMMARY_JSON_END"
"@

Import-Module Posh-SSH
$securePassword = ConvertTo-SecureString $SshPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($SshUser, $securePassword)
$session = New-SSHSession -ComputerName $SshHost -Credential $credential -AcceptKey -ConnectionTimeout 20
$sftp = New-SFTPSession -ComputerName $SshHost -Credential $credential -AcceptKey -ConnectionTimeout 20

try {
    $scriptName = "codex-getfrombank-$([Guid]::NewGuid().ToString('N')).ps1"
    $localScript = Join-Path $env:TEMP $scriptName
    $remoteTemp = "C:\Users\$SshUser\AppData\Local\Temp"
    $remoteSftpTemp = "/C:/Users/$SshUser/AppData/Local/Temp"
    $remoteScriptPath = "$remoteTemp\$scriptName"
    Set-Content -LiteralPath $localScript -Value $remoteScript -Encoding UTF8
    Set-SFTPItem -SessionId $sftp.SessionId -Path $localScript -Destination $remoteSftpTemp -Force | Out-Null

    $escapedRemoteScriptPath = $remoteScriptPath.Replace('"', '\"')
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "powershell -NoProfile -ExecutionPolicy Bypass -File `"$escapedRemoteScriptPath`"" -TimeOut ([Math]::Max($TimeoutSeconds * ($ranges.Count + 1), 120))
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
