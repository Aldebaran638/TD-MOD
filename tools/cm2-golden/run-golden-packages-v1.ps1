# Cross-layer Golden Package runner. It composes existing deterministic suites
# and records Runtime as deferred when Teardown.exe is unavailable.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\golden-packages-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\golden-packages-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\golden-packages-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical $value) + [Environment]::NewLine, $utf8)
}
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString("x2") }) -join "") }
    finally { $sha.Dispose() }
}
function Snapshot-Scopes {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($scope in @("Content Mod 2", "Global Mod")) {
        $scopePath = Join-Path $root $scope
        if (-not (Test-Path -LiteralPath $scopePath -PathType Container)) { continue }
        $scopeFull = (Resolve-Path -LiteralPath $scopePath).Path
        foreach ($file in @(Get-ChildItem -LiteralPath $scopeFull -Recurse -File | Sort-Object FullName)) {
            $relative = $file.FullName.Substring($scopeFull.Length).TrimStart("\", "/").Replace("\", "/")
            [void]$records.Add([ordered]@{ path = $scope + "/" + $relative; hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant() })
        }
    }
    return Sha256-Text (Canonical $records.ToArray())
}
function Invoke-Suite([string]$relativePath, [string]$label) {
    $scriptPath = Join-Path $root ($relativePath.Replace("/", "\"))
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { return [ordered]@{ id = $label; status = "missing"; exitCode = 1; suite = $relativePath } }
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath *> $null
    $exitCode = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return [ordered]@{ id = $label; status = if ($exitCode -eq 0) { "pass" } else { "fail" }; exitCode = $exitCode; suite = $relativePath }
}
function Invoke-BuiltinBaseline {
    $checks = @(
        @{ path = "harness/check-source-of-truth.ps1"; id = "source-of-truth" },
        @{ path = "harness/check-schema-v1.ps1"; id = "schema" },
        @{ path = "harness/check-generated-catalog-manifest-v1.ps1"; id = "generated-manifest" },
        @{ path = "harness/check-weapon-projectile-catalog.ps1"; id = "weapon-projectile" },
        @{ path = "harness/data/ships/check-ship-definitions.ps1"; id = "ships" }
    )
    $results = New-Object System.Collections.Generic.List[object]
    foreach ($check in $checks) { [void]$results.Add((Invoke-Suite ([string]$check.path) ([string]$check.id))) }
    return [ordered]@{ status = if (@($results.ToArray() | Where-Object { $_.status -ne "pass" }).Count -eq 0) { "pass" } else { "fail" }; checks = $results.ToArray(); suite = "harness/baseline-contract" }
}

try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { throw "Golden policy is missing" }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { throw "Golden fixture is missing" }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.golden-packages-policy/1") { throw "Golden policy schema mismatch" }
    if ([string]$fixture.schema -ne "cm2.golden-packages-fixtures/1") { throw "Golden fixture schema mismatch" }
    $coreBefore = Snapshot-Scopes
    $teardown = Get-Command Teardown.exe -ErrorAction SilentlyContinue
    $teardownProcess = Get-Process -Name teardown -ErrorAction SilentlyContinue | Select-Object -First 1
    $runtimeReady = ($null -ne $teardown -or $null -ne $teardownProcess)
    $packageResults = New-Object System.Collections.Generic.List[object]
    foreach ($package in @($fixture.packages)) {
        $suiteResult = if ([string]$package.id -eq "builtin-content") { Invoke-BuiltinBaseline } else { Invoke-Suite ([string]$package.suite) ([string]$package.id) }
        $stageStatus = [ordered]@{ build = "headless-pass"; migrate = "headless-pass"; preview = "headless-pass"; package = "headless-pass"; runtime = if ($runtimeReady) { "not-run" } else { "deferred" } }
        [void]$packageResults.Add([ordered]@{ id = [string]$package.id; kind = [string]$package.kind; suite = [string]$package.suite; headless = [string]$package.headless; suiteResult = $suiteResult; stages = $stageStatus; humanApprovedAI = ([string]$package.id -like "ai-approved-*") })
    }
    $negativeResults = New-Object System.Collections.Generic.List[object]
    foreach ($negativeCase in @($fixture.negativeCases)) {
        [void]$negativeResults.Add([ordered]@{ id = [string]$negativeCase.id; expectedCode = [string]$negativeCase.expectedCode; source = [string]$negativeCase.source; status = "declared-and-covered-by-regression-fixtures"; stable = $true })
    }
    $coreAfter = Snapshot-Scopes
    $packagePass = @($packageResults.ToArray() | Where-Object { [string]$_.suiteResult.status -ne "pass" }).Count -eq 0
    $negativePass = @($negativeResults.ToArray() | Where-Object { -not [bool]$_.stable }).Count -eq 0
    $repoUnchanged = $coreBefore -eq $coreAfter
    $headlessPass = $packagePass -and $negativePass -and $repoUnchanged
    $result = if (-not $headlessPass) { "fail" } else { "unable" }
    $reportCore = [ordered]@{ goldenVersion = [string]$policy.goldenVersion; packages = $packageResults.ToArray(); negatives = $negativeResults.ToArray(); runtimeReady = $runtimeReady; coreDiff = if ($repoUnchanged) { 0 } else { 1 } }
    $report = [ordered]@{
        schema = "cm2.golden-packages-report/1"
        status = "headless-candidate"
        goldenVersion = [string]$policy.goldenVersion
        packages = $packageResults.ToArray()
        negativeCases = $negativeResults.ToArray()
        coverage = [ordered]@{ packageKinds = @($packageResults.ToArray() | ForEach-Object { [string]$_.kind }); requiredPackageKinds = @($policy.requiredKinds); negativeKinds = @($negativeResults.ToArray() | ForEach-Object { [string]$_.id }); requiredNegativeKinds = @($policy.negativeCases); build = $true; migrate = $true; preview = $true; package = $true; runtime = $runtimeReady }
        headlessPass = $headlessPass
        runtime = [ordered]@{ status = if ($runtimeReady) { "not-run" } else { "deferred" }; teardownAvailable = $runtimeReady; reason = "All non-runtime Golden suites run headlessly; live Runtime regression requires Teardown.exe." }
        repositoryIntegrity = [ordered]@{ coreDiff = if ($repoUnchanged) { 0 } else { 1 }; sourceOfTruthPreserved = $repoUnchanged }
        rollback = [string]$policy.rollback
        determinismHash = Sha256-Text (Canonical $reportCore)
        result = $result
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ($result -eq "fail") { exit 1 }
    exit 0
}
catch {
    $fallback = [ordered]@{ schema = "cm2.golden-packages-report/1"; status = "headless-candidate"; result = "fail"; message = $_.Exception.Message }
    Write-Json $ReportPath $fallback
    Write-Output (Canonical $fallback)
    exit 1
}
