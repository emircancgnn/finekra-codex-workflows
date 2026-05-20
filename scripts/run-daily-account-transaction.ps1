param(
    [int]$BankId,
    [string]$TenantId,
    [string]$StartDate,
    [string]$EndDate,
    [int]$DelaySeconds = 3
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$dailyScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\invoke-daily-account-transaction.ps1"
$vaultScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\get-finekra-vault-item.ps1"
$secretFile = Join-Path $workspace "secrets\manual-process.local.json"
$outputDir = Join-Path $workspace "outputs\daily-account-transaction"

function Unprotect-Secret {
    param([string]$Value)
    if (-not $Value) { return $null }
    $secure = $Value | ConvertTo-SecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Get-LoginFromVault {
    param([string]$ItemName)
    if (-not (Test-Path -LiteralPath $vaultScript)) { return $null }
    try {
        $json = & powershell -NoProfile -ExecutionPolicy Bypass -File $vaultScript -ItemName $ItemName
        if ($LASTEXITCODE -ne 0 -or -not $json) { return $null }
        return ($json | ConvertFrom-Json)
    } catch {
        return $null
    }
}

if (-not $BankId) { $BankId = [int](Read-Host "bankId") }
if (-not $TenantId) { $TenantId = Read-Host "tenantId" }
if (-not $StartDate) { $StartDate = Read-Host "startDate (yyyy-MM-dd or dd.MM.yyyy)" }
if (-not $EndDate) {
    $endInput = Read-Host "endDate blank=today (yyyy-MM-dd or dd.MM.yyyy)"
    if ($endInput) { $EndDate = $endInput }
}
if ($DelaySeconds -lt 0) { throw "DelaySeconds cannot be negative." }

Write-Host "DailyAccountTransaction preview will be generated first." -ForegroundColor Cyan
Write-Host "BankId: $BankId"
Write-Host "TenantId: $TenantId"
Write-Host "Range: $StartDate - $(if ($EndDate) { $EndDate } else { 'today' })"
Write-Host "Mode: Daily"
Write-Host "Delay between requests: $DelaySeconds seconds"
Write-Host "Auth: no API token"
Write-Host ""

$previewArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $dailyScript,
    "-BankId", $BankId,
    "-TenantId", $TenantId,
    "-StartDate", $StartDate,
    "-DelaySeconds", $DelaySeconds
)
if ($EndDate) { $previewArgs += @("-EndDate", $EndDate) }
& powershell @previewArgs

Write-Host ""
Write-Host "No request has been sent yet." -ForegroundColor Yellow
$confirm = Read-Host "Type YES to execute these DailyAccountTransaction requests"
if ($confirm -ne "YES") {
    Write-Host "Cancelled. No request was sent." -ForegroundColor Yellow
    exit 0
}

$server58 = Get-LoginFromVault "Server 58 - emircancagin"
if ($server58 -and $server58.password) {
    $sshPassword = $server58.password
    Write-Host "Credentials: Server 58 password loaded from Vaultwarden." -ForegroundColor Green
} elseif (Test-Path -LiteralPath $secretFile) {
    $config = Get-Content -LiteralPath $secretFile -Raw | ConvertFrom-Json
    $sshPassword = Unprotect-Secret $config.sshPassword
    Write-Host "Credentials: Server 58 password loaded from encrypted local fallback." -ForegroundColor Yellow
} else {
    Write-Host "Vaultwarden item and encrypted fallback were not found." -ForegroundColor Red
    Write-Host "Expected Vaultwarden item: Server 58 - emircancagin"
    Write-Host "Fallback setup: scripts\setup-manual-process-credentials.bat"
    exit 1
}
if (-not $sshPassword) { throw "Server 58 SSH password is missing." }

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$safeTenantId = $TenantId -replace '[^a-zA-Z0-9-]', '_'
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $outputDir "daily-account-transaction-bank$BankId-$safeTenantId-$timestamp.json"

$executeArgs = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $dailyScript,
    "-BankId", $BankId,
    "-TenantId", $TenantId,
    "-StartDate", $StartDate,
    "-DelaySeconds", $DelaySeconds,
    "-SshPassword", $sshPassword,
    "-Execute"
)
if ($EndDate) { $executeArgs += @("-EndDate", $EndDate) }

$result = & powershell @executeArgs
$result | Tee-Object -FilePath $outputFile

Write-Host ""
Write-Host "Result saved to: $outputFile" -ForegroundColor Green
