# Deterministic headless performance gate. It compares every fixture sample and
# deliberately does not claim live Teardown frame-time or hardware evidence.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\performance-regression-gate-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\performance-regression-gate-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\performance-regression-gate-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)
function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) { $parent = Split-Path -Parent $path; if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }; [IO.File]::WriteAllText($path, (Canonical $value) + [Environment]::NewLine, $utf8) }
function Sha256-Text([string]$text) { $sha = [Security.Cryptography.SHA256]::Create(); try { return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString("x2") }) -join "") } finally { $sha.Dispose() } }
function Require([bool]$condition, [string]$message) { if (-not $condition) { throw ("Performance Regression Gate v1 failed: " + $message) } }
function Percentile([double[]]$values, [double]$fraction) { $sorted = @($values | Sort-Object); $index = [math]::Max(0, [math]::Ceiling($sorted.Count * $fraction) - 1); return [double]$sorted[$index] }
function RelativeStdDev([double[]]$values) { $mean = ($values | Measure-Object -Average).Average; if ($mean -eq 0) { return 0.0 }; $sum = 0.0; foreach ($v in $values) { $sum += ([double]$v - $mean) * ([double]$v - $mean) }; return [math]::Sqrt($sum / [math]::Max(1, $values.Count - 1)) / $mean }
function Invoke-Suite([string]$relative, [string]$id) { $path = Join-Path $root ($relative.Replace("/", "\")); Require (Test-Path -LiteralPath $path -PathType Leaf) ("missing S0-S8 suite: " + $relative); $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path *> $null; $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved; return [ordered]@{ id = $id; suite = $relative; status = if ($code -eq 0) { "pass" } else { "fail" }; exitCode = $code } }

try {
    Require (Test-Path -LiteralPath $PolicyPath -PathType Leaf) "policy is missing"
    Require (Test-Path -LiteralPath $FixturePath -PathType Leaf) "fixture is missing"
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    Require ([string]$policy.schema -eq "cm2.performance-regression-policy/1") "policy schema mismatch"
    Require ([string]$fixture.schema -eq "cm2.performance-regression-fixtures/1") "fixture schema mismatch"
    $metricResults = New-Object System.Collections.Generic.List[object]
    foreach ($metric in @($fixture.metrics)) {
        $baseline = @($metric.baseline | ForEach-Object { [double]$_ })
        $candidate = @($metric.candidate | ForEach-Object { [double]$_ })
        Require ($baseline.Count -ge 20 -and $baseline.Count -eq $candidate.Count) ([string]$metric.id + " sample count mismatch")
        $baseP95 = Percentile $baseline 0.95; $candidateP95 = Percentile $candidate 0.95
        $baseP99 = Percentile $baseline 0.99; $candidateP99 = Percentile $candidate 0.99
        $baseMean = ($baseline | Measure-Object -Average).Average; $candidateMean = ($candidate | Measure-Object -Average).Average
        $p95Regression = if ($baseP95 -eq 0) { 0.0 } else { ($candidateP95 - $baseP95) / $baseP95 }
        $p99Regression = if ($baseP99 -eq 0) { 0.0 } else { ($candidateP99 - $baseP99) / $baseP99 }
        $meanRegression = if ($baseMean -eq 0) { 0.0 } else { ($candidateMean - $baseMean) / $baseMean }
        $baseVariance = RelativeStdDev $baseline; $candidateVariance = RelativeStdDev $candidate
        $variancePass = $baseVariance -le [double]$policy.thresholds.maxRelativeStdDev -and $candidateVariance -le [double]$policy.thresholds.maxRelativeStdDev
        $thresholdPass = $p95Regression -le [double]$metric.p95MaxRegression -and $p99Regression -le [double]$metric.p99MaxRegression -and $meanRegression -le [double]$metric.maxRegression
        [void]$metricResults.Add([ordered]@{ id = [string]$metric.id; unit = [string]$metric.unit; sampleCount = $baseline.Count; baselineP95 = $baseP95; candidateP95 = $candidateP95; p95Regression = $p95Regression; baselineP99 = $baseP99; candidateP99 = $candidateP99; p99Regression = $p99Regression; meanRegression = $meanRegression; baselineRelativeStdDev = $baseVariance; candidateRelativeStdDev = $candidateVariance; variancePass = $variancePass; thresholdPass = $thresholdPass; status = if ($variancePass -and $thresholdPass) { "pass" } else { "fail" }; selectionPolicy = "all-samples-no-best-trial" })
    }
    $sliceResults = New-Object System.Collections.Generic.List[object]
    foreach ($slice in @($fixture.slices)) { [void]$sliceResults.Add((Invoke-Suite ([string]$slice.suite) ([string]$slice.id))) }
    $metricArray = $metricResults.ToArray()
    $sliceArray = $sliceResults.ToArray()
    $metricPass = @($metricArray | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0
    $slicePass = @($sliceArray | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0 -and $sliceArray.Count -eq 9
    $headlessPass = $metricPass -and $slicePass -and -not [bool]$fixture.declaredPerformanceTradeoff
    $teardownCommand = Get-Command Teardown.exe -ErrorAction SilentlyContinue
    $teardownProcess = Get-Process -Name teardown -ErrorAction SilentlyContinue | Select-Object -First 1
    $runtimeReady = ($null -ne $teardownCommand -or $null -ne $teardownProcess)
    $runtimeStatus = if ($runtimeReady) { "not-run" } else { "deferred" }
    $result = if (-not $headlessPass) { "fail" } else { "unable" }
    $core = [ordered]@{ metrics = $metricResults.ToArray(); slices = $sliceResults.ToArray(); nightly = @($fixture.nightly | ForEach-Object { [ordered]@{ id = [string]$_.id; suite = [string]$_.suite; status = "declared-live-required" } }); thresholds = [ordered]@{ p95MaxRegression = [double]$policy.thresholds.p95MaxRegression; p99MaxRegression = [double]$policy.thresholds.p99MaxRegression; maxRelativeStdDev = [double]$policy.thresholds.maxRelativeStdDev; variancePolicy = [string]$policy.thresholds.variancePolicy }; selectionPolicy = "all-samples-no-best-trial" }
    $report = [ordered]@{ schema = "cm2.performance-regression-report/1"; status = "headless-candidate"; baselineVersion = [string]$fixture.baselineVersion; candidateVersion = [string]$fixture.candidateVersion; headlessPass = $headlessPass; gateDecision = $result; metrics = $metricResults.ToArray(); slices = $sliceArray; nightly = $core.nightly; thresholds = $core.thresholds; variance = [ordered]@{ policy = [string]$policy.thresholds.variancePolicy; maxRelativeStdDev = [double]$policy.thresholds.maxRelativeStdDev; allSamplesEvaluated = $true }; replayPolicy = [ordered]@{ before = [string]$policy.replayPolicy.before; after = [string]$policy.replayPolicy.after; adr = [string]$policy.replayPolicy.adr; referenceHardware = [string]$policy.replayPolicy.referenceHardware }; runtime = [ordered]@{ status = $runtimeStatus; teardownAvailable = $runtimeReady; reason = "Live S0-S8 timing, hardware identity and before/after replay was not run by this headless gate; a focused Runtime operation must create the live evidence." }; rollback = [string]$policy.rollback; determinismHash = Sha256-Text (Canonical $core); result = $result }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ($result -eq "fail") { exit 1 }
    exit 0
}
catch {
    $fallback = [ordered]@{ schema = "cm2.performance-regression-report/1"; status = "headless-candidate"; result = "fail"; message = ($_.Exception.Message + " at " + $_.InvocationInfo.PositionMessage) }
    Write-Json $ReportPath $fallback
    Write-Output (Canonical $fallback)
    exit 1
}
