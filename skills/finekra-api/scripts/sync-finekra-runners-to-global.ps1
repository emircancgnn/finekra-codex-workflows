param(
    [string]$ProjectRoot = (Join-Path $env:USERPROFILE "Documents\Projects\finekra-api-work"),
    [string]$GlobalSkillRoot = (Join-Path $env:USERPROFILE ".codex\skills\finekra-api")
)

$ErrorActionPreference = "Stop"

$projectScripts = Join-Path $ProjectRoot "scripts"
$projectSkill = Join-Path $ProjectRoot ".codex\skills\finekra-api"
$templateDir = Join-Path $GlobalSkillRoot "runner-templates"

if (-not (Test-Path -LiteralPath $projectScripts)) {
    throw "Project scripts directory was not found: $projectScripts"
}
if (-not (Test-Path -LiteralPath $projectSkill)) {
    throw "Project skill directory was not found: $projectSkill"
}

New-Item -ItemType Directory -Force -Path $templateDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $GlobalSkillRoot "scripts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $GlobalSkillRoot "references") | Out-Null

$runnerPatterns = @(
    "run-*.bat",
    "run-*.ps1",
    "setup-*.bat",
    "setup-*.ps1"
)

$copiedRunners = New-Object System.Collections.Generic.List[string]
foreach ($pattern in $runnerPatterns) {
    Get-ChildItem -LiteralPath $projectScripts -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $templateDir $_.Name) -Force
        $copiedRunners.Add($_.Name)
    }
}

Copy-Item -LiteralPath (Join-Path $projectSkill "SKILL.md") -Destination (Join-Path $GlobalSkillRoot "SKILL.md") -Force
Copy-Item -Path (Join-Path $projectSkill "scripts\*.ps1") -Destination (Join-Path $GlobalSkillRoot "scripts") -Force
Copy-Item -Path (Join-Path $projectSkill "references\*.md") -Destination (Join-Path $GlobalSkillRoot "references") -Force

[pscustomobject]@{
    synced = $true
    projectRoot = $ProjectRoot
    globalSkillRoot = $GlobalSkillRoot
    runnerTemplateDir = $templateDir
    runnerCount = $copiedRunners.Count
    runners = @($copiedRunners)
    note = "Secrets and outputs were not copied."
} | ConvertTo-Json -Depth 5
