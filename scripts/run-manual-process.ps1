param(
    [string]$BankInfoId,
    [string]$StartDate,
    [string]$EndDate,
    [int]$DelaySeconds = 3
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manualScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\invoke-manual-process.ps1"
$secretFile = Join-Path $workspace "secrets\manual-process.local.json"
$outputDir = Join-Path $workspace "outputs\manual-process"

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

Write-Host "ManualProcess preview will be generated first." -ForegroundColor Cyan
Write-Host "BankInfoId: $BankInfoId"
Write-Host "Range: $StartDate - $EndDate"
Write-Host "Mode: Daily"
Write-Host "Delay between requests: $DelaySeconds seconds"
Write-Host ""

& powershell -NoProfile -ExecutionPolicy Bypass -File $manualScript `
    -BankInfoId $BankInfoId `
    -StartDate $StartDate `
    -EndDate $EndDate `
    -Daily `
    -DelaySeconds $DelaySeconds

Write-Host ""
Write-Host "No request has been sent yet." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to execute these ManualProcess requests"
if ($confirm -ne "YES") {
    Write-Host "Cancelled. No request was sent." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path -LiteralPath $secretFile)) {
    Write-Host "Encrypted credential file was not found." -ForegroundColor Red
    Write-Host "Run scripts\setup-manual-process-credentials.bat once, then run this file again."
    exit 1
}

$config = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
$sshPassword = Unprotect-Secret $config.sshPassword
if (-not $sshPassword) { throw "Server 58 SSH password is missing from encrypted credential file." }

$commonArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $manualScript,
    "-BankInfoId", $BankInfoId,
    "-StartDate", $StartDate,
    "-EndDate", $EndDate,
    "-Daily",
    "-DelaySeconds", $DelaySeconds,
    "-SshPassword", $sshPassword,
    "-Execute"
)

if ($config.authMode -eq "bearer") {
    $bearerToken = Unprotect-Secret $config.bearerToken
    if (-not $bearerToken) { throw "Bearer token is missing from encrypted credential file." }
    $commonArgs += @("-BearerToken", $bearerToken)
} else {
    $apiPassword = Unprotect-Secret $config.finekraPassword
    if (-not $config.finekraEmail -or -not $apiPassword -or -not $config.tenantCode) {
        throw "API login credentials are incomplete in encrypted credential file."
    }
    $commonArgs += @(
        "-FinekraEmail", $config.finekraEmail,
        "-FinekraPassword", $apiPassword,
        "-TenantCode", $config.tenantCode
    )
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$safeBankInfoId = $BankInfoId -replace '[^a-zA-Z0-9-]', '_'
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $outputDir "manual-process-$safeBankInfoId-$timestamp.json"

$result = & powershell @commonArgs
$result | Tee-Object -FilePath $outputFile

Write-Host ""
Write-Host "Result saved to: $outputFile" -ForegroundColor Green
