# Static contract checker for the four Event -> Ring -> EffectPlayer slices.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$module = Join-Path $root "script\weapon\client\presentation\slice_runtime.lua"
$publisher = Join-Path $root "script\net\presentation_publisher.lua"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $module -PathType Leaf)) { $issues.Add("missing slice runtime") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $module
    foreach ($slice in @("ray-beam", "logical-projectile", "guided-missile", "tachyon-charge-beam")) {
        if ($source -notmatch [regex]::Escape('"' + $slice + '"')) { $issues.Add("missing slice: $slice") }
    }
    foreach ($symbol in @("init", "tick", "disposeOwner", "getDiagnostics")) {
        if ($source -notmatch "function runtime\.$symbol\b") { $issues.Add("missing slice runtime API: $symbol") }
    }
    foreach ($token in @("presentationEventDrain", "effectPlayer.play", "effectPlayer.stop", "effectPlayer.updateAll", "trace", "sliceMode")) {
        if ($source -notmatch [regex]::Escape($token)) { $issues.Add("slice bridge missing: $token") }
    }
    if ($source -notmatch 'while #state\.trace > 256') { $issues.Add("trace must be bounded") }
    if ($source -match 'client\.weaponFxBudgetBeginFrame') { $issues.Add("slice runtime must not own frame budget reset") }
    $publisherSource = Get-Content -Raw -LiteralPath $publisher
    if ($publisherSource -notmatch 'presentationPublisherSetSliceMode') { $issues.Add("publisher slice mode API missing") }
    if ($publisherSource -notmatch 'slice mode is frozen after first publish') { $issues.Add("slice mode freeze missing") }
}
if ($issues.Count -gt 0) { Write-Error ("Presentation slice check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Presentation slice contract passed: four mappings, event drain, EffectPlayer bridge, trace and frozen per-slice mode." -ForegroundColor Green
exit 0
