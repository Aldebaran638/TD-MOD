# Regression test for the candidate-only AI Weapon Assistant.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-ai-weapon-assistant-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-ai-weapon-assistant-v1.ps1"
$policy = Join-Path $root "docs\ai-weapon-assistant-v1.json"
$fixture = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.fixture.json"
$report = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-weapon-" + [Guid]::NewGuid().ToString("N") + ".json")

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("AI Weapon Assistant v1 failed: " + $message) }
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
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "Weapon Assistant runner passes"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.ai-weapon-report/1" -and [string]$first.status -eq "candidate-only") "report declares candidate-only status"
    Assert-True ([int]$first.caseCount -eq 6 -and @($first.evaluations).Count -eq 6) "all six fixed prompts are evaluated"
    Assert-True ([double]$first.metrics.legalRate -eq 1.0 -and [double]$first.metrics.savedCompilerPassRate -eq 1.0) "legal decisions and accepted compiler saves are 100 percent"
    Assert-True ([bool]$first.humanApproval.required -and [bool]$first.humanApproval.diffDisplayed -and -not [bool]$first.humanApproval.autoPublish) "human diff is mandatory and auto-publish is disabled"
    $accepted = @($first.evaluations | Where-Object { [string]$_.decision -eq "accept" })
    Assert-True ($accepted.Count -eq 2) "two safe candidates are accepted"
    foreach ($evaluation in @($first.evaluations)) {
        Assert-True ([string]$evaluation.decision -eq [string]$evaluation.expected) ("expected decision is stable for " + [string]$evaluation.id)
        foreach ($field in @("promptHash", "candidateHash", "modelVersion", "toolVersion", "parserVersion", "validatorVersion", "humanDiff", "finalBuildHash")) {
            Assert-True ($null -ne $evaluation.PSObject.Properties[$field]) ("provenance field is present for " + [string]$evaluation.id + ": " + $field)
        }
        Assert-True (@($evaluation.humanDiff).Count -ge 1 -and [string]$evaluation.publish -eq "manual-approval-required") ("human diff and publish gate are present for " + [string]$evaluation.id)
        Assert-True ([int]$evaluation.aiWrites.generated -eq 0 -and [int]$evaluation.aiWrites.core -eq 0 -and [int]$evaluation.aiWrites.lua -eq 0) ("AI writes no generated/Core/Lua output for " + [string]$evaluation.id)
    }
    foreach ($candidate in $accepted) {
        Assert-True ([bool]$candidate.compiler.passed -and [int]$candidate.compiler.definitionCount -eq 3) ("accepted candidate compiles three definitions: " + [string]$candidate.id)
        Assert-True ([string]$candidate.rangeLab.status -eq "pass" -and [string]$candidate.rangeLab.budget.status -eq "accepted") ("Weapon Range/Effect Lab passes: " + [string]$candidate.id)
        Assert-True ([string]$candidate.finalBuildHash -ne "not-built" -and [string]$candidate.compiler.outputScope -eq "disposable-temp-only") ("compiler output is disposable and provenance-bound: " + [string]$candidate.id)
    }
    $rejectCodes = @($first.evaluations | Where-Object { [string]$_.decision -eq "reject" } | ForEach-Object { [string]$_.code })
    Assert-True ($rejectCodes -contains "permission-denied" -and $rejectCodes -contains "missing-resource" -and $rejectCodes -contains "budget-or-range-reject") "permission/resource/budget negative cases are blocked"
    Assert-True ([int]$first.aiWrites.generated -eq 0 -and [int]$first.aiWrites.core -eq 0 -and [int]$first.repositoryIntegrity.coreDiff -eq 0) "repository and generated targets remain unchanged"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second Weapon Assistant run passes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True ([string]$first.metrics.determinismHash -eq [string]$second.metrics.determinismHash) "fixed prompt evaluation is deterministic"
    Write-Host "AI Weapon Assistant v1 regression passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue }
}
