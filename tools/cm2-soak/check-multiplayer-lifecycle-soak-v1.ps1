# Static contract checker for the multiplayer, save/load and lifecycle soak.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\multiplayer-lifecycle-soak-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\multiplayer-lifecycle-soak-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }
try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: " + $_.Exception.Message) }
try { $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: " + $_.Exception.Message) }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.multiplayer-lifecycle-soak-policy/1" -and [string]$policy.status -eq "headless-candidate") "policy schema/status mismatch"
    Require ([int]$policy.durationSeconds -ge 1800 -and [int]$policy.warmupSeconds -gt 0 -and [int]$policy.tickHz -gt 0) "policy must declare at least a 30-minute soak and warmup"
    Require (@($policy.clients).Count -ge 3 -and @($policy.entityKinds).Count -eq 5) "policy must cover host, remote, late join and five entity kinds"
    Require (@($policy.requiredScenarios).Count -ge 8 -and @($policy.requiredSaveLoadCases).Count -eq 4) "policy scenario or Save/Load coverage is incomplete"
    Require ([bool]$policy.runtimePolicy.teardownRequired -and [string]$policy.runtimePolicy.statusWhenUnavailable -eq "deferred") "runtime policy must disclose missing Teardown"
}
if ($null -ne $fixture) {
    Require ([string]$fixture.schema -eq "cm2.multiplayer-lifecycle-soak-fixtures/1") "fixture schema mismatch"
    Require ([int]$fixture.durationSeconds -ge 1800 -and [int]$fixture.warmupSeconds -gt 0 -and [int]$fixture.tickHz -gt 0) "fixture duration/warmup/tick contract is incomplete"
    Require (@($fixture.clients).Count -eq 3) "fixture must contain host, remote and late-join clients"
    Require (@($fixture.scenarios).Count -eq 8) "fixture must contain eight lifecycle scenarios"
    foreach ($kind in @("Ship", "Projectile", "Craft", "Effect", "Joint")) { Require ([string]$kind -in @($fixture.entityChurn.entitiesPerCycle.PSObject.Properties.Name)) ("missing churn kind: " + $kind) }
    Require ([int]$fixture.entityChurn.cycles -ge 1800 -and [bool]$fixture.entityChurn.destroyBeforeNextCycle) "entity churn must run at least 1800 cleanup cycles"
    Require (@($fixture.saveLoad).Count -eq 4) "fixture must contain four Save/Load cases"
    foreach ($case in @("same-revision", "missing-package", "downgrade-revision", "compatible-migration")) { Require ([string]$case -in @($fixture.saveLoad.case)) ("missing Save/Load case: " + $case) }
    Require (@($fixture.sourceContracts).Count -ge 6 -and @($fixture.headlessSuites).Count -ge 6) "source and headless suite coverage is incomplete"
}
if ($issues.Count -gt 0) {
    Write-Error ("Multiplayer lifecycle soak checker failed:" + [Environment]::NewLine + " - " + ($issues -join [Environment]::NewLine + " - "))
    exit 1
}
Write-Host "Multiplayer/Lifecycle Soak v1 contract passed: 30-minute fixture, host/remote/late-join, five entity kinds, Save/Load revisions and bounded metrics are declared." -ForegroundColor Green
exit 0
