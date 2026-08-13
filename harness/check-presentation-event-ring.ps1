# Static contract checker for the bounded Presentation Event Ring.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$runtime = Join-Path $root "script\weapon\client\presentation\event_runtime.lua"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) { $issues.Add("missing event runtime") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $runtime
    foreach ($symbol in @("receiveWeaponPresentationEventV1", "presentationEventGetDiagnostics", "presentationEventDrain", "presentationEventDisposeOwner")) {
        if ($source -notmatch "function client\.$symbol\b") { $issues.Add("missing ring API: $symbol") }
    }
    if ($source -notmatch '_newRing\(128\)') { $issues.Add("critical ring capacity must be 128") }
    if ($source -notmatch '_newRing\(32\)') { $issues.Add("ambient ring capacity must be 32") }
    if ($source -notmatch 'droppedCritical') { $issues.Add("critical drop counter missing") }
    if ($source -notmatch 'droppedAmbient') { $issues.Add("ambient drop counter missing") }
    if ($source -notmatch 'duplicate') { $issues.Add("duplicate counter missing") }
    if ($source -notmatch 'gap') { $issues.Add("gap counter missing") }
    if ($source -notmatch 'outOfOrder') { $issues.Add("out-of-order counter missing") }
    if ($source -notmatch '_ambientReplaceOrPush') { $issues.Add("ambient coalescing missing") }
    if ($source -notmatch '_ringRemoveOwner') { $issues.Add("owner dispose removal missing") }
    if ($source -match 'table\.remove|table\.insert') { $issues.Add("ring must not use table.remove/table.insert") }
}
if ($issues.Count -gt 0) { Write-Error ("Presentation Event Ring check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Presentation Event Ring contract passed: fixed Critical/Ambient rings, coalescing, diagnostics, and owner dispose." -ForegroundColor Green
exit 0
