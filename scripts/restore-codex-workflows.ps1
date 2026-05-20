param(
    [string]$CodexHome = (Join-Path $env:USERPROFILE ".codex"),
    [string]$ProjectRoot = "C:\Users\EmircanÇağın\Documents\Projects\finekra-api-work"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$skillsSource = Join-Path $repoRoot "skills"
$scriptsSource = Join-Path $repoRoot "scripts"
$agentsSource = Join-Path $repoRoot "AGENTS.md"

if (-not (Test-Path -LiteralPath $skillsSource)) {
    throw "Missing skills source: $skillsSource"
}

New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $CodexHome "skills") | Out-Null
New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectRoot "scripts") | Out-Null

Get-ChildItem -LiteralPath $skillsSource -Directory | ForEach-Object {
    $target = Join-Path (Join-Path $CodexHome "skills") $_.Name
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
}

if (Test-Path -LiteralPath $agentsSource) {
    $agentsTarget = Join-Path $CodexHome "AGENTS.md"
    if (Test-Path -LiteralPath $agentsTarget) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        Copy-Item -LiteralPath $agentsTarget -Destination "$agentsTarget.bak-$stamp" -Force
    }
    Copy-Item -LiteralPath $agentsSource -Destination $agentsTarget -Force
}

$runnerNames = @(
    "run-manual-process.bat",
    "run-manual-process.ps1",
    "run-getfrombank.bat",
    "run-getfrombank.ps1",
    "run-daily-account-transaction.bat",
    "run-daily-account-transaction.ps1",
    "setup-manual-process-credentials.bat",
    "setup-manual-process-credentials.ps1"
)

foreach ($name in $runnerNames) {
    $src = Join-Path $scriptsSource $name
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path (Join-Path $ProjectRoot "scripts") $name) -Force
    }
}

[pscustomobject]@{
    codexHome = $CodexHome
    projectRoot = $ProjectRoot
    skillsRestored = (Get-ChildItem -LiteralPath (Join-Path $CodexHome "skills") -Directory | Select-Object -ExpandProperty Name)
    agentsRestored = (Test-Path -LiteralPath (Join-Path $CodexHome "AGENTS.md"))
    note = "Secrets, .env files, Vaultwarden data, and outputs were not copied."
} | ConvertTo-Json -Depth 4
