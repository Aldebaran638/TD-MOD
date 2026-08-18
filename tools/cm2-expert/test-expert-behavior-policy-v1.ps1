# Self-test for the deferred Expert Custom Behavior security boundary.

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$checker = Join-Path $PSScriptRoot "check-expert-behavior-policy-v1.ps1"
$evaluator = Join-Path $PSScriptRoot "evaluate-expert-behavior-v1.ps1"
$fixturePath = Join-Path $root "docs\candidates\expert-behavior-api-v1.fixture.json"
$policyPath = Join-Path $root "docs\expert-behavior-api-v1.json"
$resultPath = Join-Path $root "docs\candidates\expert-behavior-api-v1.result.json"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Expert behavior self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Write-Json([string]$path, [object]$value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 100) + "`n", $utf8) }
function Invoke-Tool([string]$scriptPath, [string[]]$arguments) {
    $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments *> $null
    $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved; return $code
}
function Invoke-Capture([string]$scriptPath, [string[]]$arguments) {
    $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $lines = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @arguments 2>&1)
    $code = [int]$LASTEXITCODE; $ErrorActionPreference = $saved
    return [pscustomobject]@{ Code = $code; Output = ($lines -join "`n") }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-expert-policy-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    Assert-True ((Invoke-Tool $checker @()) -eq 0) "checker accepts the deferred/default-deny policy"
    $fixtures = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
    $reports = New-Object System.Collections.Generic.List[object]
    foreach ($request in @($fixtures.requests)) {
        $requestPath = Join-Path $tempRoot (($request.name -replace "[^A-Za-z0-9]", "-") + ".json")
        $reportPath = Join-Path $tempRoot (($request.name -replace "[^A-Za-z0-9]", "-") + ".decision.json")
        Write-Json $requestPath $request
        Assert-True ((Invoke-Tool $evaluator @("-RequestPath", $requestPath, "-PolicyPath", $policyPath, "-ReportPath", $reportPath)) -eq 0) ("evaluates without executing " + $request.name)
        $decision = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
        [void]$reports.Add($decision)
        if ([string]$request.expected -eq "deferred") { Assert-True ([string]$decision.decision -eq "deferred" -and [string]$decision.code -eq "expert-api-disabled") "keeps ordinary request deferred" }
        elseif ([string]$request.expected -eq "deny") { Assert-True ([string]$decision.decision -eq "deny" -and [string]$decision.code -eq "capability-not-allowlisted") ("denies " + $request.name) }
        else { Assert-True ([string]$decision.decision -eq "isolate" -and [string]$decision.execution -eq "not-run") ("isolates " + $request.name) }
    }

    $badPolicy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
    $badPolicy.enabled = $true
    $badPolicyPath = Join-Path $tempRoot "bad-policy.json"
    Write-Json $badPolicyPath $badPolicy
    Assert-True ((Invoke-Tool $checker @("-PolicyPath", $badPolicyPath, "-FixturePath", $fixturePath)) -ne 0) "checker rejects an enabled policy before security review"

    $reportArray = @($reports.ToArray())
    $capabilityDenials = @($reportArray | Where-Object {[string]$_.code -eq "capability-not-allowlisted"}).Count
    $isolationDecisions = @($reportArray | Where-Object {[string]$_.decision -eq "isolate"}).Count
    $allExecutionNotRun = (@($reportArray | Where-Object {[string]$_.execution -ne "not-run"}).Count -eq 0)
    $result = [ordered]@{
        schema = "cm2.expert-behavior-test-report/1"
        status = "deferred"
        enabled = $false
        requestsEvaluated = $reportArray.Count
        allExecutionNotRun = $allExecutionNotRun
        capabilityDenials = $capabilityDenials
        isolationDecisions = $isolationDecisions
        securityReviewRequired = $true
        result = "pass"
    }
    [IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 30) + "`n", $utf8)
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Expert behavior policy self-test passed." -ForegroundColor Green
exit 0
