param(
    [Parameter(Mandatory = $true)][string]$TenantId,
    [Parameter(Mandatory = $true)][string]$Date,
    [ValidateSet("transactionV2", "api", "b2b", "dbs", "pos", "tos")]
    [string]$Module = "transactionV2",
    [switch]$ErrorsOnly,
    [switch]$IncludeApiCheck,
    [int]$SampleSize = 20,
    [ValidateSet("DirectElastic", "Kibana")]
    [string]$Mode = "DirectElastic",
    [string]$ElasticUrl = "http://172.16.220.59:9200",
    [string]$KibanaUrl = "http://172.16.220.59:5601",
    [string]$VaultItem = "Elastic - 172.16.220.59",
    [string]$ElasticUsername,
    [string]$ElasticPassword,
    [string]$VaultPassword,
    [string]$NodePath = "node",
    [string]$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
)

$ErrorActionPreference = "Stop"

$moduleIndexes = @{
    transactionV2 = "finekra-transactionv2-job-prod-log-*"
    api = "finekra-api-prod-log-*"
    b2b = "finekra-b2b-api-prod-log-*"
    dbs = "finekra-dbs-job-prod-log-*"
    pos = "finekra-pos-transaction-job-prod-log-*"
    tos = "finekra-tos-job-prod-log-*"
}

function Test-InternalNetwork {
    param([string]$SelectedMode)
    if ($SelectedMode -eq "DirectElastic") {
        return (Test-NetConnection -ComputerName 172.16.220.59 -Port 9200 -InformationLevel Quiet)
    }
    return (Test-NetConnection -ComputerName 172.16.220.59 -Port 5601 -InformationLevel Quiet)
}

function Get-BwExecutable {
    $cmd = Get-Command bw -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidate = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter bw.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($candidate) { return $candidate }
    throw "Bitwarden CLI (bw.exe) was not found."
}

function Get-ElasticCredential {
    if ($ElasticUsername -and $ElasticPassword) {
        return [pscustomobject]@{
            Username = $ElasticUsername
            Password = $ElasticPassword
        }
    }

    if (-not $VaultPassword) {
        if ($env:BW_MASTER_PASSWORD) {
            $VaultPassword = $env:BW_MASTER_PASSWORD
        } else {
            $secure = Read-Host "Vaultwarden master password" -AsSecureString
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            try { $VaultPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
            finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        }
    }

    $bw = Get-BwExecutable
    $certPath = Join-Path (Resolve-Path ".").Path "vaultwarden\ssl\cert.pem"
    if (Test-Path -LiteralPath $certPath) {
        $env:NODE_EXTRA_CA_CERTS = $certPath
    }

    $session = & $bw unlock $VaultPassword --raw
    if (-not $session) { throw "Could not unlock Vaultwarden." }
    $item = & $bw get item $VaultItem --session $session | ConvertFrom-Json
    if (-not $item.login.username -or -not $item.login.password) {
        throw "Vault item '$VaultItem' does not contain a username/password login."
    }
    return [pscustomobject]@{
        Username = $item.login.username
        Password = $item.login.password
    }
}

function Convert-DateRange {
    param([string]$InputDate)
    $culture = [Globalization.CultureInfo]::GetCultureInfo("tr-TR")
    $styles = [Globalization.DateTimeStyles]::AssumeLocal
    $formats = @("yyyy-MM-dd", "dd.MM.yyyy", "d.M.yyyy", "yyyy/MM/dd")
    $parsed = $null
    foreach ($format in $formats) {
        try {
            $parsed = [DateTime]::ParseExact($InputDate, $format, $culture, $styles)
            break
        } catch {}
    }
    if (-not $parsed) {
        $parsed = [DateTime]::Parse($InputDate, $culture)
    }
    $startLocal = [DateTime]::SpecifyKind($parsed.Date, [DateTimeKind]::Local)
    $endLocal = $startLocal.AddDays(1)
    return [pscustomobject]@{
        LocalDate = $startLocal.ToString("yyyy-MM-dd")
        GteUtc = $startLocal.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        LtUtc = $endLocal.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
}

function Get-BasicAuthHeader {
    param([string]$Username, [string]$Password)
    $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
    return "Basic $token"
}

function Invoke-ElasticSearch {
    param(
        [string]$BaseUrl,
        [string]$Index,
        [hashtable]$Body,
        [hashtable]$Headers
    )
    $uri = "{0}/{1}/_search" -f $BaseUrl.TrimEnd('/'), $Index
    $jsonBody = $Body | ConvertTo-Json -Depth 20 -Compress
    return Invoke-RestMethod -Method Post -Uri $uri -Headers $Headers -ContentType "application/json" -Body $jsonBody -TimeoutSec 120
}

function Get-TotalValue {
    param($Raw)
    if ($Raw.hits.total -is [int] -or $Raw.hits.total -is [long]) { return [int]$Raw.hits.total }
    if ($Raw.hits.total.value -is [int] -or $Raw.hits.total.value -is [long]) { return [int]$Raw.hits.total.value }
    return 0
}

function Get-AggBuckets {
    param($Raw, [string]$Name)
    $buckets = (($Raw.aggregations.$Name).buckets)
    if (-not $buckets) { return @() }
    return @($buckets | ForEach-Object {
        [pscustomobject]@{
            key = $_.key
            count = $_.doc_count
        }
    })
}

function Summarize-Hit {
    param($Hit)
    $s = $Hit._source
    [pscustomobject]@{
        index = $Hit._index
        id = $Hit._id
        timestamp = $s.'@timestamp'
        level = $(if ($s.level) { $s.level } elseif ($s.Level) { $s.Level } elseif ($s.log.level) { $s.log.level } else { $null })
        message = $(if ($s.message) { $s.message } elseif ($s.Message) { $s.Message } else { $s.messageTemplate })
        messageTemplate = $s.messageTemplate
        sourceContext = $s.SourceContext
        requestPath = $(if ($s.RequestPath) { $s.RequestPath } elseif ($s.requestPath) { $s.requestPath } elseif ($s.Path) { $s.Path } else { $s.path })
        statusCode = $(if ($s.StatusCode) { $s.StatusCode } elseif ($s.statusCode) { $s.statusCode } else { $s.ResponseStatusCode })
        eventId = $s.EventId
        bankAccountJobId = $s.BankAccountJobId
        bankJobId = $s.BankJobId
    }
}

function New-TenantFilter {
    param([string]$TenantIdValue, [string]$GteUtc, [string]$LtUtc)
    return @(
        @{ range = @{ '@timestamp' = @{ gte = $GteUtc; lt = $LtUtc } } },
        @{ query_string = @{ query = '"' + $TenantIdValue + '"'; default_operator = 'AND' } }
    )
}

function New-StrictErrorShould {
    return @(
        @{ terms = @{ 'level.keyword' = @('Error', 'Fatal', 'Warning', 'Warn', 'Critical') } },
        @{ exists = @{ field = 'Exception' } },
        @{ exists = @{ field = 'exception' } },
        @{ exists = @{ field = 'Error' } },
        @{ exists = @{ field = 'error' } },
        @{ query_string = @{ query = '(hata OR error OR exception OR fail OR failed OR fatal OR timeout OR "basarisiz")' } }
    )
}

function Search-DirectElastic {
    param(
        [string]$Index,
        [string]$TenantIdValue,
        [string]$GteUtc,
        [string]$LtUtc,
        [int]$RequestedSampleSize,
        [bool]$OnlyErrors,
        [hashtable]$Headers,
        [string]$BaseUrl
    )
    $tenantFilter = New-TenantFilter -TenantIdValue $TenantIdValue -GteUtc $GteUtc -LtUtc $LtUtc
    $strictErrorShould = New-StrictErrorShould

    $aggsBody = @{
        size = 0
        track_total_hits = $true
        query = @{ bool = @{ filter = $tenantFilter } }
        aggs = @{
            levels = @{ terms = @{ field = 'level.keyword'; size = 20; missing = '__missing__' } }
            messages = @{ terms = @{ field = 'messageTemplate.keyword'; size = 30; missing = '__missing__' } }
            sourceContexts = @{ terms = @{ field = 'SourceContext.keyword'; size = 20; missing = '__missing__' } }
            requestPaths = @{ terms = @{ field = 'RequestPath.keyword'; size = 20; missing = '__missing__' } }
        }
    }

    $sampleQuery = if ($OnlyErrors) {
        @{ bool = @{ filter = $tenantFilter; should = $strictErrorShould; minimum_should_match = 1 } }
    } else {
        @{ bool = @{ filter = $tenantFilter } }
    }

    $sampleBody = @{
        size = $RequestedSampleSize
        track_total_hits = $true
        query = $sampleQuery
        sort = @(@{ '@timestamp' = @{ order = 'asc'; unmapped_type = 'date' } })
    }

    $errorBody = @{
        size = $RequestedSampleSize
        track_total_hits = $true
        query = @{ bool = @{ filter = $tenantFilter; should = $strictErrorShould; minimum_should_match = 1 } }
        sort = @(@{ '@timestamp' = @{ order = 'asc'; unmapped_type = 'date' } })
    }

    $aggsRaw = Invoke-ElasticSearch -BaseUrl $BaseUrl -Index $Index -Body $aggsBody -Headers $Headers
    $sampleRaw = Invoke-ElasticSearch -BaseUrl $BaseUrl -Index $Index -Body $sampleBody -Headers $Headers
    $errorRaw = Invoke-ElasticSearch -BaseUrl $BaseUrl -Index $Index -Body $errorBody -Headers $Headers

    return [pscustomobject]@{
        totalLogs = Get-TotalValue $aggsRaw
        errorLogs = Get-TotalValue $errorRaw
        levelDistribution = @(Get-AggBuckets -Raw $aggsRaw -Name "levels")
        messageDistribution = @(Get-AggBuckets -Raw $aggsRaw -Name "messages")
        sourceContextDistribution = @(Get-AggBuckets -Raw $aggsRaw -Name "sourceContexts")
        requestPathDistribution = @(Get-AggBuckets -Raw $aggsRaw -Name "requestPaths")
        samples = @($sampleRaw.hits.hits | ForEach-Object { Summarize-Hit $_ })
        errorSamples = @($errorRaw.hits.hits | ForEach-Object { Summarize-Hit $_ })
    }
}

function Search-Kibana {
    param(
        [pscustomobject]$Credential,
        [pscustomobject]$Range,
        [string]$Index,
        [string]$ApiIndex,
        [int]$SampleSizeSafe
    )
    if (-not (Test-Path -LiteralPath $ChromePath)) {
        throw "Chrome executable not found at $ChromePath"
    }
    $workspaceRoot = (Resolve-Path ".").Path
    $nodeModules = Join-Path $workspaceRoot "vaultwarden\node_modules"
    if (Test-Path -LiteralPath $nodeModules) {
        $env:NODE_PATH = $nodeModules
    }

    $payload = @{
        tenantId = $TenantId
        module = $Module
        index = $Index
        apiIndex = $ApiIndex
        errorsOnly = [bool]$ErrorsOnly
        includeApiCheck = [bool]$IncludeApiCheck
        sampleSize = $SampleSizeSafe
        kibanaUrl = $KibanaUrl.TrimEnd("/")
        username = $Credential.Username
        password = $Credential.Password
        chromePath = $ChromePath
        gteUtc = $Range.GteUtc
        ltUtc = $Range.LtUtc
        localDate = $Range.LocalDate
    } | ConvertTo-Json -Compress

    $env:FINEKRA_LOG_SEARCH_PAYLOAD = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))

    $script = @'
const { chromium } = require('playwright-core');
const payload = JSON.parse(Buffer.from(process.env.FINEKRA_LOG_SEARCH_PAYLOAD, 'base64').toString('utf8'));
function summarizeHit(hit) {
  const s = hit._source || {};
  return {
    index: hit._index, id: hit._id, timestamp: s['@timestamp'],
    level: s.level || s.Level || (s.log && s.log.level),
    message: s.message || s.Message || s.messageTemplate,
    messageTemplate: s.messageTemplate, sourceContext: s.SourceContext,
    requestPath: s.RequestPath || s.requestPath || s.Path || s.path,
    statusCode: s.StatusCode || s.statusCode || s.ResponseStatusCode,
    eventId: s.EventId, bankAccountJobId: s.BankAccountJobId, bankJobId: s.BankJobId
  };
}
async function kibanaSearch(page, index, body) {
  const response = await page.evaluate(async ({ index, body }) => {
    const res = await fetch('/internal/search/es', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'kbn-xsrf': 'codex' },
      body: JSON.stringify({ params: { index, body }, serverStrategy: 'ese' })
    });
    return { status: res.status, json: await res.json().catch(async () => ({ text: await res.text() })) };
  }, { index, body });
  if (response.status >= 400) throw new Error(`Kibana search failed for ${index}: HTTP ${response.status}`);
  return response.json.rawResponse || response.json;
}
async function ensureLoggedIn(page) {
  await page.waitForTimeout(1500);
  if (page.url().includes('/login') || await page.locator('input[name="username"]').count()) {
    await page.locator('input[name="username"]').waitFor({ timeout: 30000 });
    await page.locator('input[name="username"]').fill(payload.username);
    await page.locator('input[name="password"]').fill(payload.password);
    await page.locator('button[type="submit"]').click();
    await page.waitForURL(/app\//, { timeout: 60000 });
  }
}
function totalValue(raw) {
  const total = raw.hits && raw.hits.total;
  if (typeof total === 'number') return total;
  if (total && typeof total.value === 'number') return total.value;
  return 0;
}
function aggBuckets(raw, name) {
  return (((raw.aggregations || {})[name] || {}).buckets || []).map(b => ({ key: b.key, count: b.doc_count }));
}
(async () => {
  const browser = await chromium.launch({ executablePath: payload.chromePath, headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  try {
    await page.goto(payload.kibanaUrl + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
    await ensureLoggedIn(page);
    const tenantFilter = [
      { range: { '@timestamp': { gte: payload.gteUtc, lt: payload.ltUtc } } },
      { query_string: { query: `"${payload.tenantId}"`, default_operator: 'AND' } }
    ];
    const strictErrorShould = [
      { terms: { 'level.keyword': ['Error', 'Fatal', 'Warning', 'Warn', 'Critical'] } },
      { exists: { field: 'Exception' } }, { exists: { field: 'exception' } },
      { exists: { field: 'Error' } }, { exists: { field: 'error' } },
      { query_string: { query: '(hata OR error OR exception OR fail OR failed OR fatal OR timeout OR "basarisiz")' } }
    ];
    const aggsBody = { size: 0, track_total_hits: true, query: { bool: { filter: tenantFilter } }, aggs: {
      levels: { terms: { field: 'level.keyword', size: 20, missing: '__missing__' } },
      messages: { terms: { field: 'messageTemplate.keyword', size: 30, missing: '__missing__' } },
      sourceContexts: { terms: { field: 'SourceContext.keyword', size: 20, missing: '__missing__' } },
      requestPaths: { terms: { field: 'RequestPath.keyword', size: 20, missing: '__missing__' } }
    }};
    const sampleBody = { size: payload.sampleSize, track_total_hits: true, query: payload.errorsOnly
      ? { bool: { filter: tenantFilter, should: strictErrorShould, minimum_should_match: 1 } }
      : { bool: { filter: tenantFilter } }, sort: [{ '@timestamp': { order: 'asc', unmapped_type: 'date' } }] };
    const errorBody = { size: payload.sampleSize, track_total_hits: true, query: { bool: { filter: tenantFilter, should: strictErrorShould, minimum_should_match: 1 } }, sort: [{ '@timestamp': { order: 'asc', unmapped_type: 'date' } }] };
    const [aggsRaw, sampleRaw, errorRaw] = await Promise.all([
      kibanaSearch(page, payload.index, aggsBody),
      kibanaSearch(page, payload.index, sampleBody),
      kibanaSearch(page, payload.index, errorBody)
    ]);
    const result = {
      totalLogs: totalValue(aggsRaw), errorLogs: totalValue(errorRaw),
      levelDistribution: aggBuckets(aggsRaw, 'levels'),
      messageDistribution: aggBuckets(aggsRaw, 'messages'),
      sourceContextDistribution: aggBuckets(aggsRaw, 'sourceContexts'),
      requestPathDistribution: aggBuckets(aggsRaw, 'requestPaths'),
      samples: (sampleRaw.hits.hits || []).map(summarizeHit),
      errorSamples: (errorRaw.hits.hits || []).map(summarizeHit)
    };
    if (payload.includeApiCheck && payload.module !== 'api') {
      const apiAggsRaw = await kibanaSearch(page, payload.apiIndex, aggsBody);
      const apiErrorRaw = await kibanaSearch(page, payload.apiIndex, errorBody);
      result.apiCheck = {
        index: payload.apiIndex,
        totalLogs: totalValue(apiAggsRaw),
        errorLogs: totalValue(apiErrorRaw),
        levelDistribution: aggBuckets(apiAggsRaw, 'levels'),
        messageDistribution: aggBuckets(apiAggsRaw, 'messages'),
        requestPathDistribution: aggBuckets(apiAggsRaw, 'requestPaths'),
        errorSamples: (apiErrorRaw.hits.hits || []).map(summarizeHit)
      };
    }
    console.log(JSON.stringify(result));
  } finally { await browser.close(); }
})().catch(err => { console.error(err.stack || String(err)); process.exit(1); });
'@

    $tempScript = Join-Path $env:TEMP "search-finekra-logs-$([Guid]::NewGuid().ToString('N')).js"
    try {
        Set-Content -LiteralPath $tempScript -Value $script -Encoding UTF8
        return (& $NodePath $tempScript | Out-String | ConvertFrom-Json)
    } finally {
        Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\FINEKRA_LOG_SEARCH_PAYLOAD -ErrorAction SilentlyContinue
    }
}

if (-not (Test-InternalNetwork -SelectedMode $Mode)) {
    if ($Mode -eq "DirectElastic") {
        throw "Elasticsearch is not reachable at 172.16.220.59:9200. Connect Finekra VPN first."
    }
    throw "Kibana is not reachable at 172.16.220.59:5601. Connect Finekra VPN first."
}

$credential = Get-ElasticCredential
$range = Convert-DateRange $Date
$index = $moduleIndexes[$Module]
$apiIndex = $moduleIndexes["api"]
$sampleSizeSafe = [Math]::Max(0, [Math]::Min($SampleSize, 100))

if ($Mode -eq "Kibana") {
    $searchResult = Search-Kibana -Credential $credential -Range $range -Index $index -ApiIndex $apiIndex -SampleSizeSafe $sampleSizeSafe
    $result = [ordered]@{
        tenantId = $TenantId
        date = $range.LocalDate
        module = $Module
        index = $index
        mode = $Mode
        utcRange = @{ gte = $range.GteUtc; lt = $range.LtUtc }
        totalLogs = $searchResult.totalLogs
        errorLogs = $searchResult.errorLogs
        levelDistribution = @($searchResult.levelDistribution)
        messageDistribution = @($searchResult.messageDistribution)
        sourceContextDistribution = @($searchResult.sourceContextDistribution)
        requestPathDistribution = @($searchResult.requestPathDistribution)
        samples = @($searchResult.samples)
        errorSamples = @($searchResult.errorSamples)
    }
    if ($searchResult.apiCheck) { $result.apiCheck = $searchResult.apiCheck }
    $result | ConvertTo-Json -Depth 20
    exit 0
}

$headers = @{
    Authorization = Get-BasicAuthHeader -Username $credential.Username -Password $credential.Password
    Accept = "application/json"
}

$primary = Search-DirectElastic -Index $index -TenantIdValue $TenantId -GteUtc $range.GteUtc -LtUtc $range.LtUtc -RequestedSampleSize $sampleSizeSafe -OnlyErrors ([bool]$ErrorsOnly) -Headers $headers -BaseUrl $ElasticUrl

$result = [ordered]@{
    tenantId = $TenantId
    date = $range.LocalDate
    module = $Module
    index = $index
    mode = $Mode
    utcRange = @{ gte = $range.GteUtc; lt = $range.LtUtc }
    totalLogs = $primary.totalLogs
    errorLogs = $primary.errorLogs
    levelDistribution = @($primary.levelDistribution)
    messageDistribution = @($primary.messageDistribution)
    sourceContextDistribution = @($primary.sourceContextDistribution)
    requestPathDistribution = @($primary.requestPathDistribution)
    samples = @($primary.samples)
    errorSamples = @($primary.errorSamples)
}

if ($IncludeApiCheck -and $Module -ne "api") {
    $api = Search-DirectElastic -Index $apiIndex -TenantIdValue $TenantId -GteUtc $range.GteUtc -LtUtc $range.LtUtc -RequestedSampleSize $sampleSizeSafe -OnlyErrors $false -Headers $headers -BaseUrl $ElasticUrl
    $result.apiCheck = [ordered]@{
        index = $apiIndex
        totalLogs = $api.totalLogs
        errorLogs = $api.errorLogs
        levelDistribution = @($api.levelDistribution)
        messageDistribution = @($api.messageDistribution)
        requestPathDistribution = @($api.requestPathDistribution)
        errorSamples = @($api.errorSamples)
    }
}

$result | ConvertTo-Json -Depth 20
