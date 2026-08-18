# Headless AI authoring evaluation and provenance runner.
# This runner evaluates candidates only; it never writes Core, Runtime, Lua, or
# generated artifacts and never invokes a model, network, or Teardown runtime.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\ai-evaluation-provenance-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\ai-evaluation-provenance-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\ai-evaluation-provenance-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Canonical([object]$value) {
    return ($value | ConvertTo-Json -Depth 100 -Compress)
}
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($path, (Canonical $value) + [Environment]::NewLine, $utf8)
}
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally { $sha.Dispose() }
}
function Fail([string]$code, [string]$message, [string]$fieldPath, [string]$suggestion) {
    $report = [ordered]@{
        schema = "cm2.ai-evaluation-report/1"
        status = "evaluation-only"
        result = "fail"
        code = $code
        fieldPath = $fieldPath
        message = $message
        suggestion = $suggestion
        runtimeWrites = 0
        generatedWrites = 0
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    exit 1
}
function Evaluate-Case([object]$testCase, [object]$policy, [object]$fixture) {
    $candidate = $testCase.candidate
    $candidateHash = Sha256-Text (Canonical $candidate)
    $decision = "accept"
    $code = "accepted"
    $repair = ""
    $manualEdits = @()
    $confidence = [double]$candidate.confidence
    $permissions = @($candidate.permissions | ForEach-Object { [string]$_ })
    $targetText = (([string]$candidate.target) + "|" + ([string]$candidate.path))
    $forbiddenTarget = $targetText -match '(^|[\\/])\.\.([\\/]|$)|Global Mod|Core|generated|\.lua($|[\\/])'
    $deniedPermission = @($permissions | Where-Object { [string]$_ -in @($policy.permissions.deny) })

    if (-not [bool]$candidate.provenance) {
        $decision = "reject"
        $code = "missing-provenance"
    }
    elseif ([string]$candidate.operation -notin @($policy.permissions.allow)) {
        $decision = "reject"
        $code = "operation-not-allowlisted"
    }
    elseif ($deniedPermission.Count -gt 0) {
        $decision = "reject"
        $code = "permission-denied:" + ($deniedPermission -join ",")
    }
    elseif ($forbiddenTarget) {
        $decision = "reject"
        $code = "forbidden-target"
    }
    elseif ([bool]$candidate.duplicateId) {
        $decision = "reject"
        $code = "duplicate-id"
    }
    elseif ([bool]$candidate.budgetOverflow) {
        $decision = "reject"
        $code = "budget-overflow"
    }
    elseif ([bool]$candidate.ambiguous) {
        $decision = "repair"
        $code = "ambiguous-repair-required"
        $repair = [string]$candidate.repair
    }
    elseif ([bool]$candidate.missingResource) {
        $decision = "repair"
        $code = "missing-resource-repair-required"
        $repair = [string]$candidate.repair
    }
    elseif ($null -ne $candidate.manualEdits -and @($candidate.manualEdits).Count -gt 0) {
        $decision = "human-review"
        $code = "manual-review-required"
        $manualEdits = @($candidate.manualEdits | ForEach-Object { [string]$_ })
    }

    $finalBuildHash = if ($decision -eq "accept") { "deferred:" + $candidateHash } else { "not-built" }
    return [ordered]@{
        id = [string]$testCase.id
        category = [string]$testCase.category
        expected = [string]$testCase.expected
        decision = $decision
        code = $code
        inputHash = [string]$fixture.inputHash
        promptHash = [string]$fixture.promptHash
        modelVersion = [string]$policy.modelVersion
        toolVersion = [string]$policy.toolVersion
        seed = [int]$policy.seed
        candidateHash = $candidateHash
        validatorVersion = [string]$fixture.validatorVersion
        repair = $repair
        confidence = $confidence
        humanEdits = $manualEdits
        finalBuildHash = $finalBuildHash
        runtimeWrites = 0
        generatedWrites = 0
        provenanceComplete = $true
    }
}

try {
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) { Fail "policy-missing" "AI evaluation policy does not exist" "policy" "Restore the reviewed policy." }
    if (-not (Test-Path -LiteralPath $FixturePath -PathType Leaf)) { Fail "fixture-missing" "AI evaluation fixture does not exist" "fixture" "Restore the ten-category fixture." }
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    if ([string]$policy.schema -ne "cm2.ai-evaluation-policy/1") { Fail "policy-schema" "AI evaluation policy schema mismatch" "policy.schema" "Use the reviewed policy v1." }
    if ([string]$fixture.schema -ne "cm2.ai-evaluation-fixtures/1") { Fail "fixture-schema" "AI evaluation fixture schema mismatch" "fixture.schema" "Use the fixture v1." }

    $evaluations = New-Object System.Collections.Generic.List[object]
    foreach ($testCase in @($fixture.cases)) {
        [void]$evaluations.Add((Evaluate-Case $testCase $policy $fixture))
    }
    $matching = @($evaluations.ToArray() | Where-Object { [string]$_.decision -eq [string]$_.expected }).Count
    $legalRate = if ($evaluations.Count -eq 0) { 0.0 } else { [Math]::Round($matching / $evaluations.Count, 4) }
    $determinismHash = Sha256-Text (Canonical $evaluations.ToArray())
    $teardown = Get-Command Teardown.exe -ErrorAction SilentlyContinue
    $report = [ordered]@{
        schema = "cm2.ai-evaluation-report/1"
        status = "evaluation-only"
        policySchema = [string]$policy.schema
        modelVersion = [string]$policy.modelVersion
        toolVersion = [string]$policy.toolVersion
        seed = [int]$policy.seed
        caseCount = $evaluations.Count
        evaluations = $evaluations.ToArray()
        metrics = [ordered]@{
            accepted = @($evaluations.ToArray() | Where-Object { $_.decision -eq "accept" }).Count
            repairs = @($evaluations.ToArray() | Where-Object { $_.decision -eq "repair" }).Count
            rejected = @($evaluations.ToArray() | Where-Object { $_.decision -eq "reject" }).Count
            humanReview = @($evaluations.ToArray() | Where-Object { $_.decision -eq "human-review" }).Count
            legalRate = $legalRate
            determinismHash = $determinismHash
            performanceRisk = "bounded-headless-evaluation"
        }
        permissions = [ordered]@{
            default = [string]$policy.permissions.default
            humanApprovalRequired = [bool]$policy.permissions.humanApprovalRequired
            runtimeWrites = 0
            generatedWrites = 0
            coreWrites = 0
            networkCalls = 0
        }
        runtime = [ordered]@{
            teardownAvailable = ($null -ne $teardown)
            status = if ($null -eq $teardown) { "deferred" } else { "not-run" }
            reason = "Evaluation is intentionally editor/runtime-free; candidates are not executed."
        }
        result = if ($legalRate -eq 1.0 -and $evaluations.Count -eq 10) { "pass" } else { "fail" }
    }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ([string]$report.result -ne "pass") { exit 1 }
    exit 0
}
catch {
    Fail "ai-evaluation-runner-error" $_.Exception.Message "runner" "Inspect the policy and fixture, then rerun the headless evaluator."
}
