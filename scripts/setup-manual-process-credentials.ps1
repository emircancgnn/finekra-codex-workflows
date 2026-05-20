$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$secretDir = Join-Path $workspace "secrets"
$secretFile = Join-Path $secretDir "manual-process.local.json"

function Read-PlainSecret {
    param([string]$Prompt)
    $secure = Read-Host $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Protect-Secret {
    param([string]$Value)
    ConvertTo-SecureString $Value -AsPlainText -Force | ConvertFrom-SecureString
}

New-Item -ItemType Directory -Force -Path $secretDir | Out-Null

Write-Host "ManualProcess credentials will be stored encrypted with Windows DPAPI." -ForegroundColor Cyan
Write-Host "They can be decrypted only by this Windows user on this machine."
Write-Host ""

$sshPassword = Read-PlainSecret "Server 58 SSH password"
$authMode = Read-Host "Use Bearer token? Type YES for token, otherwise API login will be stored"

$config = [ordered]@{
    createdAt = (Get-Date).ToString("o")
    sshHost = "172.16.220.58"
    sshUser = "emircancagin"
    sshPassword = Protect-Secret $sshPassword
    authMode = $null
    bearerToken = $null
    finekraEmail = $null
    finekraPassword = $null
    tenantCode = $null
}

if ($authMode -eq "YES") {
    $config.authMode = "bearer"
    $config.bearerToken = Protect-Secret (Read-PlainSecret "ManualProcess Bearer token")
} else {
    $config.authMode = "login"
    $config.finekraEmail = Read-Host "ManualProcess API email"
    $config.finekraPassword = Protect-Secret (Read-PlainSecret "ManualProcess API password")
    $config.tenantCode = Read-Host "ManualProcess tenantCode"
}

$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $secretFile -Encoding UTF8
Write-Host ""
Write-Host "Saved encrypted credentials to: $secretFile" -ForegroundColor Green
Write-Host "Next runs of the ManualProcess .bat will only ask for YES confirmation."
