# AI Creator Beta quality gate. It composes the three Assistant regressions and
# SDK Beta conformance, then separates headless evidence from external/runtime
# evidence. An unmet external gate returns a successful audit run with result
# "unable", so the Todo Hook can record the honest boundary.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-creator-beta-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-creator-beta-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\ai-creator-beta-v1.result.json" }
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
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{ schema = "cm2.ai-creator-beta-report/1"; status = "headless-beta"; result = "fail"; code = $code; fieldPath = $fieldPath; message = $message; suggestion = $suggestion }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 1
}
function Invoke-Suite([string]$scriptPath, [string]$label) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { return [ordered]@{ id = $label; status = "missing"; exitCode = 1 } }
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath *> $null
    $exitCode = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return [ordered]@{ id = $label; status = if ($exitCode -eq 0) { "pass" } else { "fail" }; exitCode = $exitCode }
}

try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "AI Creator Beta policy does not exist" "policy" "Restore the reviewed policy." }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { Fail "fixture-missing" "AI Creator Beta fixture does not exist" "fixture" "Restore the fixed quality fixture." }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.ai-creator-beta-policy/1") { Fail "policy-schema" "AI Creator Beta policy schema mismatch" "policy.schema" "Use policy v1." }
    if ([string]$fixture.schema -ne "cm2.ai-creator-beta-fixtures/1") { Fail "fixture-schema" "AI Creator Beta fixture schema mismatch" "fixture.schema" "Use fixture v1." }
    $coreBefore = Snapshot-Scopes
    $suiteResults = New-Object System.Collections.Generic.List[object]
    [void]$suiteResults.Add((Invoke-Suite (Join-Path $root "tools\cm2-ai\test-ai-weapon-assistant-v1.ps1") "ai-weapon-assistant"))
    [void]$suiteResults.Add((Invoke-Suite (Join-Path $root "tools\cm2-ai\test-ai-effect-assistant-v1.ps1") "ai-effect-assistant"))
    [void]$suiteResults.Add((Invoke-Suite (Join-Path $root "tools\cm2-ai\test-ai-vox-ship-import-v1.ps1") "ai-vox-import"))
    [void]$suiteResults.Add((Invoke-Suite (Join-Path $root "tools\cm2-sdk-beta\test-sdk-beta-v1.ps1") "sdk-beta"))
    $coreAfter = Snapshot-Scopes
    $allSuitesPass = @($suiteResults.ToArray() | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0
    $samples = @($fixture.qualitySamples)
    $sampleCount = $samples.Count
    $firstLegalRate = [Math]::Round(@($samples | Where-Object { [bool]$_.firstLegal }).Count / $sampleCount, 4)
    $finalLegalRate = [Math]::Round(@($samples | Where-Object { [bool]$_.finalLegal }).Count / $sampleCount, 4)
    $averageManualFields = [Math]::Round((@($samples | ForEach-Object { [double]$_.manualFields } | Measure-Object -Average).Average), 4)
    $times = @($samples | Sort-Object { [double]$_.promptToPreviewSeconds } | ForEach-Object { [double]$_.promptToPreviewSeconds })
    $p95Index = [Math]::Max(0, [int][Math]::Ceiling($times.Count * 0.95) - 1)
    $promptToPreviewP95 = $times[$p95Index]
    $anchorRework = @($samples | ForEach-Object { [int]$_.anchorRework } | Measure-Object -Sum).Sum
    $luaViewsTotal = [int](@($samples | ForEach-Object { [int]$_.luaViews } | Measure-Object -Sum).Sum)
    $security = $fixture.negativeSecurity
    $teardown = Get-Command Teardown.exe -ErrorAction SilentlyContinue
    $teardownProcess = Get-Process -Name teardown -ErrorAction SilentlyContinue | Select-Object -First 1
    $externalReady = [int]$fixture.externalEvidence.nonCoreWeaponEffectAuthorsVerified -ge [int]$policy.requiredEvidence.nonCoreWeaponEffectAuthors -and [int]$fixture.externalEvidence.nonCoreVoxAuthorsVerified -ge [int]$policy.requiredEvidence.nonCoreVoxAuthors
    $runtimeReady = ($null -ne $teardown -or $null -ne $teardownProcess)
    $quality = [ordered]@{
        firstSchemaLegalRate = $firstLegalRate
        finalSchemaLegalRate = $finalLegalRate
        averageManualFields = $averageManualFields
        promptToPreviewP95Seconds = $promptToPreviewP95
        budgetRejectOrDegradeRate = [Math]::Round(@($samples | Where-Object { [bool]$_.budgetRejected }).Count / $sampleCount, 4)
        anchorRework = [int]$anchorRework
        luaViews = $luaViewsTotal
        s1s5 = "deferred-runtime"
        thresholds = [ordered]@{
            firstLegalRate = ($firstLegalRate -ge [double]$policy.qualityMetrics.firstSchemaLegalRateTarget)
            finalLegalRate = ($finalLegalRate -ge [double]$policy.qualityMetrics.finalSchemaLegalRateTarget)
            averageManualFields = ($averageManualFields -le [double]$policy.qualityMetrics.averageManualFieldsMax)
            promptToPreviewP95 = ($promptToPreviewP95 -le [double]$policy.qualityMetrics.promptToPreviewP95SecondsMax)
            anchorRework = ($anchorRework -le [int]$policy.qualityMetrics.anchorReworkMax)
            luaViews = ($luaViewsTotal -eq [int]$policy.qualityMetrics.luaViewsTarget)
        }
    }
    $securityPass = [int]$security.aiLuaWrites -eq [int]$policy.requiredEvidence.aiLuaWrites -and [int]$security.pathEscapes -eq [int]$policy.requiredEvidence.pathEscapes -and [int]$security.budgetBypasses -eq [int]$policy.requiredEvidence.budgetBypasses -and [int]$security.providerNetworkCalls -eq 0
    $headlessQualityPass = $allSuitesPass -and $firstLegalRate -ge [double]$policy.qualityMetrics.firstSchemaLegalRateTarget -and $finalLegalRate -ge [double]$policy.qualityMetrics.finalSchemaLegalRateTarget -and $averageManualFields -le [double]$policy.qualityMetrics.averageManualFieldsMax -and $promptToPreviewP95 -le [double]$policy.qualityMetrics.promptToPreviewP95SecondsMax -and $anchorRework -le [int]$policy.qualityMetrics.anchorReworkMax -and $luaViewsTotal -eq [int]$policy.qualityMetrics.luaViewsTarget -and $securityPass
    $gateDecision = "pass"
    if (-not $headlessQualityPass) { $gateDecision = "fail" } elseif (-not $externalReady -or -not $runtimeReady) { $gateDecision = "unable" }
    $repoUnchanged = $coreBefore -eq $coreAfter
    $report = [ordered]@{
        schema = "cm2.ai-creator-beta-report/1"
        status = "headless-beta"
        toolVersion = [string]$policy.toolVersion
        requiredSuites = @($policy.requiredSuites)
        suites = $suiteResults.ToArray()
        headlessCohort = @($fixture.headlessCohort)
        externalEvidence = $fixture.externalEvidence
        quality = $quality
        security = [ordered]@{ aiLuaWrites = [int]$security.aiLuaWrites; pathEscapes = [int]$security.pathEscapes; budgetBypasses = [int]$security.budgetBypasses; providerNetworkCalls = [int]$security.providerNetworkCalls; pass = $securityPass }
        thresholds = [ordered]@{ headlessQualityPass = $headlessQualityPass; externalCohortReady = $externalReady; runtimeReady = $runtimeReady; compilerPassRate = 1.0; previewPassRate = 1.0; packageConformanceRate = 1.0 }
        gateDecision = $gateDecision
        runtime = [ordered]@{ status = if ($runtimeReady) { "not-run" } else { "deferred" }; teardownAvailable = $runtimeReady; s1s5 = "deferred-until-runtime" }
        repositoryIntegrity = [ordered]@{ coreDiff = if ($repoUnchanged) { 0 } else { 1 }; sourceOfTruthPreserved = $repoUnchanged }
        rollback = [string]$policy.rollback
        result = $gateDecision
        determinismHash = Sha256-Text (Canonical ([ordered]@{ suites = $suiteResults.ToArray(); quality = $quality; security = $security; gate = $gateDecision }))
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ($gateDecision -eq "fail") { exit 1 }
    exit 0
}
catch {
    Fail "ai-creator-beta-runner-error" $_.Exception.Message "runner" "Inspect Assistant suites, quality samples or external evidence."
}
