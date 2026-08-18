# Regression test for the AI evaluation/provenance boundary.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-ai-evaluation-v1.ps1"
$runner = Join-Path $PSScriptRoot "run-ai-evaluation-v1.ps1"
$policy = Join-Path $root "docs\ai-evaluation-provenance-v1.json"
$fixture = Join-Path $root "docs\candidates\ai-evaluation-provenance-v1.fixture.json"
$report = Join-Path $root "docs\candidates\ai-evaluation-provenance-v1.result.json"
$secondReport = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-evaluation-" + [Guid]::NewGuid().ToString("N") + ".json")

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("AI evaluation v1 failed: " + $message) }
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
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $report)) -eq 0) "headless evaluator passes"
    Assert-True (Test-Path -LiteralPath $report -PathType Leaf) "evaluation report is written"
    $first = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json
    Assert-True ([string]$first.schema -eq "cm2.ai-evaluation-report/1" -and [string]$first.status -eq "evaluation-only") "report declares evaluation-only status"
    Assert-True ([int]$first.caseCount -eq 10 -and @($first.evaluations).Count -eq 10) "all ten evaluation categories are executed"
    foreach ($evaluation in @($first.evaluations)) {
        Assert-True ([string]$evaluation.decision -eq [string]$evaluation.expected) ("expected decision is stable for " + [string]$evaluation.id)
        foreach ($field in @("modelVersion", "toolVersion", "seed", "inputHash", "promptHash", "candidateHash", "validatorVersion", "repair", "confidence", "humanEdits", "finalBuildHash")) {
            Assert-True ($null -ne $evaluation.PSObject.Properties[$field]) ("provenance field is present for " + [string]$evaluation.id + ": " + $field)
        }
        Assert-True ([int]$evaluation.runtimeWrites -eq 0 -and [int]$evaluation.generatedWrites -eq 0) ("no artifact writes for " + [string]$evaluation.id)
    }
    Assert-True ([double]$first.metrics.legalRate -eq 1.0) "legal decision rate is 100 percent"
    Assert-True ([int]$first.permissions.runtimeWrites -eq 0 -and [int]$first.permissions.generatedWrites -eq 0 -and [int]$first.permissions.networkCalls -eq 0) "permission boundary records zero side effects"
    Assert-True ((Invoke-Script $runner @("-PolicyPath", $policy, "-FixturePath", $fixture, "-ReportPath", $secondReport)) -eq 0) "second evaluator run passes"
    $second = Get-Content -Raw -LiteralPath $secondReport | ConvertFrom-Json
    Assert-True (([string]$first.metrics.determinismHash -eq [string]$second.metrics.determinismHash) -and ([string]$first.modelVersion -eq [string]$second.modelVersion)) "repeated evaluation is deterministic"
    Write-Host "AI evaluation/provenance v1 regression passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $secondReport) { Remove-Item -LiteralPath $secondReport -Force -ErrorAction SilentlyContinue }
}
