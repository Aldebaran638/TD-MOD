# Static contract checker for the synthetic Effect Lab MVP.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$module = Join-Path $root "script\weapon\client\presentation\effect_lab.lua"
$fixture = Join-Path (Split-Path -Parent $root) "harness\data\presentation\effect-lab-fixtures.json"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $module -PathType Leaf)) { $issues.Add("missing Effect Lab module") }
if (-not (Test-Path -LiteralPath $fixture -PathType Leaf)) { $issues.Add("missing Effect Lab fixture") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $module
    foreach ($symbol in @("init", "setDefinition", "play", "pause", "stop", "replay", "tick", "getReport", "reset")) {
        if ($source -notmatch "function lab\.$symbol\b") { $issues.Add("missing Effect Lab API: $symbol") }
    }
    foreach ($token in @("effectPlayer.init", "effectPlayer.play", "effectPlayer.update", "presentationBudget.beginFrame", "origin", "direction", "hitPoint", "hitNormal", "targetAnchor", "trace")) {
        if ($source -notmatch [regex]::Escape($token)) { $issues.Add("Effect Lab contract missing: $token") }
    }
    if ($source -match 'registryShip|GetBodyTransform|GetBodyCenterOfMass|FindBodies|GetVehicleBody') { $issues.Add("Effect Lab must not depend on real ship registry/body state") }
    if ($source -notmatch 'lab:synthetic') { $issues.Add("synthetic owner missing") }
    $data = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    if ($data.registryDependency -ne $false -or [int]$data.fixedSeed -ne 424242) { $issues.Add("fixture registry/seed contract mismatch") }
    foreach ($operation in @("init", "definition", "play", "pause", "stop", "replay", "update", "reset")) {
        if (@($data.operations) -notcontains $operation) { $issues.Add("fixture missing operation: $operation") }
    }
    if (@($data.slices).Count -ne 4 -or @($data.definitions).Count -ne 4) { $issues.Add("fixture must cover four slices and four generated definitions") }
}
if ($issues.Count -gt 0) { Write-Error ("Effect Lab check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Effect Lab contract passed: synthetic context, production Player/Budget, four definitions, seed/LOD/report APIs." -ForegroundColor Green
exit 0
