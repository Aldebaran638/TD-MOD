# Static contract check for the transport-neutral PresentationEvent v1 module.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$modulePath = Join-Path $root "script\net\presentation_event_v1.lua"
$fixturePath = Join-Path (Split-Path -Parent $root) "harness\data\net\presentation-event-v1-fixtures.json"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) { $issues.Add("missing presentation_event_v1.lua") }
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) { $issues.Add("missing PresentationEvent fixture") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $modulePath
    foreach ($symbol in @("newDefinitionRef", "newEntityRef", "newAnchorRef", "newEffectInstanceRef", "validate", "encode", "decode", "semanticEqual")) {
        if ($source -notmatch "function event\.$symbol\b") { $issues.Add("missing event API: $symbol") }
    }
    foreach ($kind in @("charge", "muzzle", "beam", "projectile", "impact", "sound", "shake", "craft_launch", "craft_recover")) {
        if ($source -notmatch "\b$kind\s*=\s*true") { $issues.Add("missing event kind: $kind") }
    }
    foreach ($forbidden in @("callback", "functionName", "engineHandle", "sharedTable")) {
        if ($source -notmatch [regex]::Escape($forbidden)) { $issues.Add("forbidden reference guard missing: $forbidden") }
    }
    if ($source -notmatch 'value\.sequence\s*<=\s*previousSequence') { $issues.Add("stale/duplicate sequence guard missing") }
    if ($source -match '#include|GetBody|GetVehicle|PlaySound|Spawn') { $issues.Add("DTO module must not depend on engine APIs or includes") }
    $fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
    if ([string]$fixture.protocolVersion -ne "cm2.presentation-event/1") { $issues.Add("fixture protocol version is not v1") }
    if ($null -eq $fixture.valid.source -or $fixture.valid.seed -lt 0) { $issues.Add("valid fixture is incomplete") }
    if (@($fixture.negative.PSObject.Properties.Name).Count -lt 5) { $issues.Add("negative fixture coverage is incomplete") }
}
if ($issues.Count -gt 0) { Write-Error ("PresentationEvent v1 check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "PresentationEvent v1 contract passed: Identity DTOs, 9 kinds, sequence/generation/version guards." -ForegroundColor Green
exit 0
