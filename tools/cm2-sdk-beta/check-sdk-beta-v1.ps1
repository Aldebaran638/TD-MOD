# Static checker for the Creator SDK Beta conformance plan.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\sdk-beta-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\sdk-beta-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }
try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: $($_.Exception.Message)") }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: $($_.Exception.Message)") }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.creator-sdk-beta/1" -and [string]$policy.status -eq "headless-beta") "Beta policy schema/status mismatch"
    Require (@($policy.cohort).Count -eq 3) "Beta cohort must contain three author profiles"
    foreach ($author in @($policy.cohort)) { Require (-not [bool]$author.editorRequired) ("Editor is required by profile: " + [string]$author.id); Require (@($author.workflow).Count -ge 5) ("workflow is incomplete: " + [string]$author.id) }
    Require (@($policy.resolvedBlockers).Count -ge 4) "resolved blocker record is incomplete"
    foreach ($blocker in @($policy.resolvedBlockers)) { Require ([string]$blocker.status -eq "resolved" -and [string]$blocker.resolution -ne "") ("blocker is not resolved: " + [string]$blocker.id) }
    Require ([int]$policy.externalEvidence.authorsInvited -eq 0 -and [string]$policy.externalEvidence.status -eq "deferred") "external evidence must be honest/deferred"
    Require ([bool]$policy.acceptance.repeatableBuild -and [bool]$policy.acceptance.editorFree) "Beta acceptance must include repeatable/editor-free build"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.creator-sdk-beta-fixtures/1") "Beta fixture schema mismatch"
    foreach ($suite in @($fixture.requiredSuites)) { Require (Test-Path -LiteralPath (Join-Path $root $suite) -PathType Leaf) ("required suite missing: " + [string]$suite) }
    Require (@($fixture.cohortIds).Count -eq 3 -and @($fixture.blockerIds).Count -ge 4) "fixture cohort/blocker coverage is incomplete"
}
if ($issues.Count -gt 0) { Write-Error ("SDK Beta checker failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Creator SDK Beta v1 passed: three cohort profiles, resolved blockers, conformance suites and deferred runtime evidence are declared." -ForegroundColor Green
exit 0
