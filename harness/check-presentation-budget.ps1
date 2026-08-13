# Static contract checker for the Presentation Budget facade and direct-call gate.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$facade = Join-Path $root "script\weapon\client\presentation\presentation_budget.lua"
$fixture = Join-Path (Split-Path -Parent $root) "harness\data\presentation\direct-call-fixtures.json"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $facade -PathType Leaf)) { $issues.Add("missing presentation budget facade") }
if (-not (Test-Path -LiteralPath $fixture -PathType Leaf)) { $issues.Add("missing direct-call fixture") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $facade
    foreach ($symbol in @("beginFrame", "spawnParticle", "pointLight", "sprite", "line", "playSound", "requestShake", "getDiagnostics")) {
        if ($source -notmatch "function budget\.$symbol\b") { $issues.Add("missing budget API: $symbol") }
    }
    foreach ($field in @("requests", "accepted", "degraded", "rejected", "byKind", "beginCount")) {
        if ($source -notmatch "\b$field\s*=") { $issues.Add("budget metric missing: $field") }
    }
    $fixtureData = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    if ([string]$fixtureData.facade -ne "presentation_budget.lua") { $issues.Add("fixture facade name mismatch") }
    $highRisk = @(
        "script\ship\common\client\effects\ship_destroyed_fx.lua",
        "script\weapon\client\presentation\audio\sound_service.lua"
    )
    foreach ($relative in $highRisk) {
        $file = Join-Path $root $relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $issues.Add("missing high-risk facade integration: $relative"); continue }
        $text = Get-Content -Raw -LiteralPath $file
        if ($text -cmatch '\b(SpawnParticle|PointLight|DrawSprite|DrawLine|PlaySound)\s*\(') {
            $issues.Add("direct presentation call remains outside facade: $relative")
        }
        if ($text -notmatch 'presentationBudget\.') { $issues.Add("facade is not used by high-risk path: $relative") }
    }
    $dispatch = Get-Content -Raw -LiteralPath (Join-Path $root "script\weapon\client\presentation\visual\runtime\registry\effect_dispatch.lua")
    if ($dispatch -match 'function client\.weaponFxTickAll[\s\S]*?weaponFxBudgetBeginFrame') { $issues.Add("effect dispatch still owns a second budget begin") }
    foreach ($relative in @("script\client.lua", "script\strikeCraftMain.lua")) {
        $text = Get-Content -Raw -LiteralPath (Join-Path $root $relative)
        if (([regex]::Matches($text, 'presentationBudget\.beginFrame\(')).Count -ne 1) { $issues.Add("entry must call beginFrame exactly once: $relative") }
    }
    foreach ($relative in @("script\weapon\client\presentation\visual\phase\impact\tachyon_lance.lua", "script\weapon\client\presentation\visual\phase\impact\perdition_beam.lua")) {
        $text = Get-Content -Raw -LiteralPath (Join-Path $root $relative)
        if ($text -notmatch 'weaponFxTakeParticles') { $issues.Add("transitional high-cost renderer lost explicit budget reservation: $relative") }
    }
}
if ($issues.Count -gt 0) { Write-Error ("Presentation Budget check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Presentation Budget contract passed: one begin owner, facade metrics, high-risk integrations, and direct-call gate." -ForegroundColor Green
exit 0
