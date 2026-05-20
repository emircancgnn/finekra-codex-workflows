param(
    [Parameter(Mandatory = $true)][string]$ItemName,
    [string]$VaultPassword,
    [switch]$AsObject
)

$ErrorActionPreference = "Stop"

function Get-BwExecutable {
    $cmd = Get-Command bw -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $wingetCandidate = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter bw.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if ($wingetCandidate) { return $wingetCandidate }

    throw "Bitwarden CLI (bw.exe) was not found. Install Bitwarden CLI or keep using the local encrypted fallback."
}

function Read-PlainSecret {
    param([string]$Prompt)
    $secure = Read-Host $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Get-FieldValue {
    param($Item, [string]$FieldName)
    $field = @($Item.fields | Where-Object { $_.name -eq $FieldName } | Select-Object -First 1)
    if ($field) { return $field.value }
    return $null
}

$bw = Get-BwExecutable
$status = & $bw status | ConvertFrom-Json
$session = $env:BW_SESSION

if ($status.status -eq "unauthenticated") {
    throw "Bitwarden CLI is not logged in. Run 'bw login' for the Vaultwarden account first."
}

if (-not $session) {
    if ($env:BW_MASTER_PASSWORD) {
        $VaultPassword = $env:BW_MASTER_PASSWORD
    } else {
        if (-not $VaultPassword) {
            $VaultPassword = Read-PlainSecret "Vaultwarden master password"
        }
    }
    $session = & $bw unlock $VaultPassword --raw
}

if (-not $session) { throw "Could not unlock Bitwarden/Vaultwarden." }

$itemJson = & $bw get item $ItemName --session $session 2>$null
if (-not $itemJson) {
    throw "Vault item '$ItemName' was not found."
}

$item = $itemJson | ConvertFrom-Json
$result = [ordered]@{
    name = $item.name
    username = $item.login.username
    password = $item.login.password
    uri = if ($item.login.uris) { $item.login.uris[0].uri } else { $null }
    tenantCode = Get-FieldValue -Item $item -FieldName "tenantCode"
    email = Get-FieldValue -Item $item -FieldName "email"
    notes = $item.notes
}

if ($AsObject) {
    [pscustomobject]$result
} else {
    [pscustomobject]$result | ConvertTo-Json -Depth 5
}
