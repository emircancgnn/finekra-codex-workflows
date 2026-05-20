param(
    [string]$BankInfoId,
    [string]$StartDate,
    [string]$EndDate,
    [int]$DelaySeconds = 3
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manualScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\invoke-manual-process.ps1"
$vaultScript = Join-Path $workspace ".codex\skills\finekra-api\scripts\get-finekra-vault-item.ps1"
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

$config = $null
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

$manualApi = Get-LoginFromVault "Finekra ManualProcess API - finekra-api@emircan.com"
if ($manualApi -and $manualApi.password -and ($manualApi.tenantCode -or $manualApi.notes)) {
    $tenantCode = if ($manualApi.tenantCode) { $manualApi.tenantCode } else { ($manualApi.notes -split "`r?`n" | Where-Object { $_ -match 'tenantCode\s*[:=]\s*(.+)' } | ForEach-Object { $Matches[1].Trim() } | Select-Object -First 1) }
    if (-not $tenantCode) { throw "Vault item 'Finekra ManualProcess API - finekra-api@emircan.com' is missing tenantCode custom field or note." }
    $commonArgs += @(
        "-FinekraEmail", $(if ($manualApi.email) { $manualApi.email } else { $manualApi.username }),
        "-FinekraPassword", $manualApi.password,
        "-TenantCode", $tenantCode
    )
    Write-Host "Credentials: ManualProcess API login loaded from Vaultwarden." -ForegroundColor Green
} elseif ($config -and $config.authMode -eq "bearer") {
    $bearerToken = Unprotect-Secret $config.bearerToken
    if (-not $bearerToken) { throw "Bearer token is missing from encrypted credential file." }
    $commonArgs += @("-BearerToken", $bearerToken)
    Write-Host "Credentials: ManualProcess bearer token loaded from encrypted local fallback." -ForegroundColor Yellow
} elseif ($config) {
    $apiPassword = Unprotect-Secret $config.finekraPassword
    if (-not $config.finekraEmail -or -not $apiPassword -or -not $config.tenantCode) {
        throw "API login credentials are incomplete in encrypted credential file."
    }
    $commonArgs += @(
        "-FinekraEmail", $config.finekraEmail,
        "-FinekraPassword", $apiPassword,
        "-TenantCode", $config.tenantCode
    )
    Write-Host "Credentials: ManualProcess API login loaded from encrypted local fallback." -ForegroundColor Yellow
} else {
    Write-Host "ManualProcess API credential was not found in Vaultwarden or encrypted fallback." -ForegroundColor Red
    Write-Host "Expected Vaultwarden item: Finekra ManualProcess API - finekra-api@emircan.com"
    Write-Host "Add custom field: tenantCode"
    exit 1
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$safeBankInfoId = $BankInfoId -replace '[^a-zA-Z0-9-]', '_'
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $outputDir "manual-process-$safeBankInfoId-$timestamp.json"

$result = & powershell @commonArgs
$result | Tee-Object -FilePath $outputFile

Write-Host ""
Write-Host "Result saved to: $outputFile" -ForegroundColor Green
