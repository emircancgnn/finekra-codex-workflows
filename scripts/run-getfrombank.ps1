param(
    [string]$BankInfoId,
    [string]$StartDate,
    [string]$EndDate,
    [int]$DelaySeconds = 3
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$getFromBankScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\invoke-getfrombank.ps1"
$secretFile = Join-Path $workspace "secrets\manual-process.local.json"
$outputDir = Join-Path $workspace "outputs\getfrombank"

function Unprotect-Secret {
    param([string]$Value)
    if (-not $Value) { return $null }
    $secure = $Value | ConvertTo-SecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

if (-not $BankInfoId) { $BankInfoId = Read-Host "bankInfoId" }
if (-not $StartDate) { $StartDate = Read-Host "startDate (yyyy-MM-dd or dd.MM.yyyy)" }
if (-not $EndDate) { $EndDate = Read-Host "endDate (yyyy-MM-dd or dd.MM.yyyy)" }
if ($DelaySeconds -lt 0) { throw "DelaySeconds cannot be negative." }

Write-Host "GetFromBank preview will be generated first." -ForegroundColor Cyan
Write-Host "BankInfoId: $BankInfoId"
Write-Host "Range: $StartDate - $EndDate"
Write-Host "Mode: Daily"
Write-Host "Delay between requests: $DelaySeconds seconds"
Write-Host "Auth: no API token"
Write-Host ""

& powershell -NoProfile -ExecutionPolicy Bypass -File $getFromBankScript `
    -BankInfoId $BankInfoId `
    -StartDate $StartDate `
    -EndDate $EndDate `
    -Daily `
    -DelaySeconds $DelaySeconds

Write-Host ""
Write-Host "No request has been sent yet." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to execute these GetFromBank requests"
if ($confirm -ne "YES") {
    Write-Host "Cancelled. No request was sent." -ForegroundColor Yellow
    exit 0
}

$sshPassword = $null
if (Test-Path -LiteralPath $secretFile) {
    $config = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
    $sshPassword = Unprotect-Secret $config.sshPassword
    Write-Host "Credentials: Server 58 password loaded from encrypted local credential file." -ForegroundColor Green
}

if (-not $sshPassword) {
    Write-Host "Encrypted local credential file was not found or did not contain Server 58 password." -ForegroundColor Red
    Write-Host "Expected local file: $secretFile"
    Write-Host "Fallback setup: scripts\setup-manual-process-credentials.bat"
    Write-Host "Vaultwarden will not be used by this runner." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "Vaultwarden master password will not be requested in this run." -ForegroundColor Green
}
if (-not $sshPassword) { throw "Server 58 SSH password is missing." }

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$safeBankInfoId = $BankInfoId -replace '[^a-zA-Z0-9-]', '_'
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $outputDir "getfrombank-$safeBankInfoId-$timestamp.json"

Write-Host ""
Write-Host "Executing GetFromBank requests on Server 58. Live progress:" -ForegroundColor Cyan
Write-Host ""

$culture = [Globalization.CultureInfo]::GetCultureInfo("tr-TR")
$dateFormats = @("yyyy-MM-dd", "dd.MM.yyyy", "d.M.yyyy", "yyyy/MM/dd")
$startDay = $null
$endDay = $null
foreach ($format in $dateFormats) {
    if (-not $startDay) {
        try { $startDay = [DateTime]::ParseExact($StartDate, $format, $culture).Date } catch {}
    }
    if (-not $endDay) {
        try { $endDay = [DateTime]::ParseExact($EndDate, $format, $culture).Date } catch {}
    }
}
if (-not $startDay) { $startDay = [DateTime]::Parse($StartDate, $culture).Date }
if (-not $endDay) { $endDay = [DateTime]::Parse($EndDate, $culture).Date }
if ($endDay -lt $startDay) { throw "EndDate must be greater than or equal to StartDate." }

$days = @()
$cursor = $startDay
while ($cursor -le $endDay) {
    $days += $cursor
    $cursor = $cursor.AddDays(1)
}

"GetFromBank live execution started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Tee-Object -FilePath $outputFile
"BankInfoId: $BankInfoId" | Tee-Object -FilePath $outputFile -Append
"Day count: $($days.Count)" | Tee-Object -FilePath $outputFile -Append

$okCount = 0
$errorCount = 0
for ($i = 0; $i -lt $days.Count; $i++) {
    $day = $days[$i].ToString("yyyy-MM-dd")
    $label = "[{0}/{1}] {2}" -f ($i + 1), $days.Count, $day
    Write-Host "START $label" -ForegroundColor Cyan
    "START $label" | Tee-Object -FilePath $outputFile -Append | Out-Null

    $dayOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $getFromBankScript `
        -BankInfoId $BankInfoId `
        -StartDate $day `
        -EndDate $day `
        -DelaySeconds 0 `
        -SshPassword $sshPassword `
        -Execute

    $dayOutput | Tee-Object -FilePath $outputFile -Append

    $joinedOutput = ($dayOutput | Out-String)
    if ($joinedOutput -match '"ok"\s*:\s*true') {
        $okCount++
        Write-Host "OK    $label" -ForegroundColor Green
        "OK    $label" | Tee-Object -FilePath $outputFile -Append | Out-Null
    } else {
        $errorCount++
        Write-Host "ERROR $label" -ForegroundColor Red
        "ERROR $label" | Tee-Object -FilePath $outputFile -Append | Out-Null
    }

    if ($DelaySeconds -gt 0 -and $i -lt ($days.Count - 1)) {
        Write-Host "WAIT  $DelaySeconds seconds"
        "WAIT  $DelaySeconds seconds" | Tee-Object -FilePath $outputFile -Append | Out-Null
        Start-Sleep -Seconds $DelaySeconds
    }
}

Write-Host ""
Write-Host "Summary: OK=$okCount ERROR=$errorCount TOTAL=$($days.Count)" -ForegroundColor Cyan
"Summary: OK=$okCount ERROR=$errorCount TOTAL=$($days.Count)" | Tee-Object -FilePath $outputFile -Append | Out-Null

Write-Host ""
Write-Host "Result saved to: $outputFile" -ForegroundColor Green
