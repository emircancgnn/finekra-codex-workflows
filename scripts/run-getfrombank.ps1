param(
    [string]$BankInfoId,
    [string]$StartDate,
    [string]$EndDate,
    [int]$DelaySeconds = 3
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$getFromBankScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\invoke-getfrombank.ps1"
$vaultScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\get-finekra-vault-item.ps1"
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
$safeBankInfoId = $BankInfoId -replace '[^a-zA-Z0-9-]', '_'
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $outputDir "getfrombank-$safeBankInfoId-$timestamp.json"

$result = & powershell -NoProfile -ExecutionPolicy Bypass -File $getFromBankScript `
    -BankInfoId $BankInfoId `
    -StartDate $StartDate `
    -EndDate $EndDate `
    -Daily `
    -DelaySeconds $DelaySeconds `
    -SshPassword $sshPassword `
    -Execute

$result | Tee-Object -FilePath $outputFile

Write-Host ""
Write-Host "Result saved to: $outputFile" -ForegroundColor Green
