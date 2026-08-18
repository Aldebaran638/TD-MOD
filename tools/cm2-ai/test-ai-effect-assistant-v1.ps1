# Regression test for the candidate-only AI Effect Assistant.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-ai-effect-assistant-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-ai-effect-assistant-v1.ps1"
$policy = Join-Path $root "docs\ai-effect-assistant-v1.json"
$fixture = Join-Path $root "docs\candidates\ai-effect-assistant-v1.fixture.json"
$report = Join-Path $root "docs\candidates\ai-effect-assistant-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-effect-" + [Guid]::NewGuid().ToString("N") + ".json")

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("AI Effect Assistant v1 failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Script([string]$path, [string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @arguments *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return $code
}

try {
    Assert-True ((Invoke-Script $checker @("-PolicyPath", $policy, "-FixturePath", $fixture)) -eq 0) "static policy/fixture checker passes"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "Effect Assistant runner passes"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.ai-effect-report/1" -and [string]$first.status -eq "candidate-only") "report declares candidate-only status"
    Assert-True ([int]$first.caseCount -eq 6 -and @($first.evaluations).Count -eq 6) "all six fixed effect prompts are evaluated"
    Assert-True ([double]$first.metrics.legalRate -eq 1.0 -and [double]$first.metrics.profileCompilerPassRate -eq 1.0) "legal decisions and all budget profiles compile"
    Assert-True ([bool]$first.humanApproval.required -and [bool]$first.humanApproval.diffDisplayed -and -not [bool]$first.humanApproval.autoPublish) "human diff is mandatory and auto-publish is disabled"
    Assert-True ([string]$first.facade.required -eq "EffectPlayer+PresentationBudget" -and -not [bool]$first.facade.customRendererAllowed) "all effects use the production facade and custom renderers are denied"
    $accepted = @($first.evaluations | Where-Object { [string]$_.decision -eq "accept" })
    Assert-True ($accepted.Count -eq 2) "two safe effect intents are accepted"
    foreach ($evaluation in @($first.evaluations)) {
        Assert-True ([string]$evaluation.decision -eq [string]$evaluation.expected) ("expected decision is stable for " + [string]$evaluation.id)
        foreach ($field in @("promptHash", "candidateHash", "modelVersion", "toolVersion", "parserVersion", "validatorVersion", "humanDiff", "finalBuildHash")) {
            Assert-True ($null -ne $evaluation.PSObject.Properties[$field]) ("provenance field is present for " + [string]$evaluation.id + ": " + $field)
        }
        Assert-True (@($evaluation.humanDiff).Count -ge 1 -and [string]$evaluation.publish -eq "manual-approval-required") ("human diff and publish gate are present for " + [string]$evaluation.id)
        Assert-True ([int]$evaluation.aiWrites.generated -eq 0 -and [int]$evaluation.aiWrites.core -eq 0 -and [int]$evaluation.aiWrites.lua -eq 0) ("AI writes no generated/Core/Lua output for " + [string]$evaluation.id)
    }
    foreach ($candidate in $accepted) {
        Assert-True (@($candidate.profiles).Count -eq 3) ("three budget profiles are generated: " + [string]$candidate.id)
        Assert-True (@($candidate.profiles | Where-Object { [bool]$_.degraded }).Count -eq 2) ("critical and ambient profiles are degraded explicitly: " + [string]$candidate.id)
        Assert-True (@($candidate.profiles | Where-Object { -not [bool]$_.compiler.passed }).Count -eq 0) ("all profiles pass the shared Compiler: " + [string]$candidate.id)
        Assert-True ([string]$candidate.effectLab.status -eq "pass" -and [int]$candidate.effectLab.accepted -eq 2 -and [int]$candidate.effectLab.degraded -eq 2 -and [int]$candidate.effectLab.hardCap -eq 12) ("near/far Effect Lab hard-cap trace passes: " + [string]$candidate.id)
        Assert-True ([string]$candidate.finalBuildHash -ne "not-built" -and [string]$candidate.facade -eq "EffectPlayer+PresentationBudget") ("compiled provenance and facade ownership are recorded: " + [string]$candidate.id)
    }
    $rejectCodes = @($first.evaluations | Where-Object { [string]$_.decision -eq "reject" } | ForEach-Object { [string]$_.code })
    Assert-True ($rejectCodes -contains "permission-denied" -and $rejectCodes -contains "missing-resource" -and $rejectCodes -contains "budget-or-range-reject") "permission/resource/budget negative cases are blocked"
    Assert-True ([int]$first.aiWrites.generated -eq 0 -and [int]$first.aiWrites.core -eq 0 -and [int]$first.repositoryIntegrity.coreDiff -eq 0) "repository and generated targets remain unchanged"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second Effect Assistant run passes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.metrics.determinismHash -eq [string]$second.metrics.determinismHash) "fixed effect prompt evaluation is deterministic"
    Write-Host "AI Effect Assistant v1 regression passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue }
}
