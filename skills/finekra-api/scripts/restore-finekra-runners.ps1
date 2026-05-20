param(
    [string]$ProjectRoot = (Join-Path $env:USERPROFILE "Documents\Projects\finekra-api-work")
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$templateDir = Join-Path $skillRoot "runner-templates"
$projectScripts = Join-Path $ProjectRoot "scripts"
$projectSkill = Join-Path $ProjectRoot ".codex\skills\finekra-api"

if (-not (Test-Path -LiteralPath $templateDir)) {
    throw "Runner template directory was not found: $templateDir"
}

New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
New-Item -ItemType Directory -Force -Path $projectScripts | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot "outputs\manual-process") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot "outputs\getfrombank") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot "outputs\daily-account-transaction") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot "secrets") | Out-Null

Copy-Item -LiteralPath (Join-Path $templateDir "*") -Destination $projectScripts -Force

if (Test-Path -LiteralPath $projectSkill) {
    Remove-Item -LiteralPath $projectSkill -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $projectSkill) | Out-Null
Copy-Item -LiteralPath $skillRoot -Destination $projectSkill -Recurse -Force

$gitignore = Join-Path $ProjectRoot ".gitignore"
if (-not (Test-Path -LiteralPath $gitignore)) {
    @"
# Secrets
.env
.env.*
*.secret.*
secrets/
vaultwarden/.env
vaultwarden/vw-data/
vaultwarden/ssl/

# Local outputs
outputs/
tmp/
*.log
tmp-*.png
vaultwarden/node_modules/
vaultwarden/package-lock.json

# OS/editor
.DS_Store
Thumbs.db
.vscode/
"@ | Set-Content -LiteralPath $gitignore -Encoding UTF8
}

$readme = Join-Path $ProjectRoot "README.md"
if (-not (Test-Path -LiteralPath $readme)) {
    @"
# Finekra API Work

Persistent local workspace for Finekra runner scripts.

Common runners:

```powershell
.\scripts\run-manual-process.bat
.\scripts\run-getfrombank.bat
.\scripts\run-daily-account-transaction.bat
```

Run `.\scripts\setup-manual-process-credentials.bat` once if encrypted local credentials are missing.
"@ | Set-Content -LiteralPath $readme -Encoding UTF8
}

$secretFile = Join-Path $ProjectRoot "secrets\manual-process.local.json"

[pscustomobject]@{
    restored = $true
    projectRoot = $ProjectRoot
    scripts = $projectScripts
    projectSkill = $projectSkill
    credentialFileExists = (Test-Path -LiteralPath $secretFile)
    nextStep = if (Test-Path -LiteralPath $secretFile) {
        "Run scripts\run-manual-process.bat, scripts\run-getfrombank.bat, or scripts\run-daily-account-transaction.bat."
    } else {
        "Run scripts\setup-manual-process-credentials.bat once before executing runners."
    }
} | ConvertTo-Json -Depth 5
