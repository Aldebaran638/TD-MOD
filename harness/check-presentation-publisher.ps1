# Static contract checker for the Step 2.1 Presentation Publisher boundary.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $Path).Path
$publisher = Join-Path $root "script\net\presentation_publisher.lua"
$eventRuntime = Join-Path $root "script\weapon\client\presentation\event_runtime.lua"
$issues = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $publisher -PathType Leaf)) { $issues.Add("missing presentation publisher") }
if (-not (Test-Path -LiteralPath $eventRuntime -PathType Leaf)) { $issues.Add("missing client event runtime") }
if ($issues.Count -eq 0) {
    $source = Get-Content -Raw -LiteralPath $publisher
    foreach ($symbol in @("presentationPublisherInit", "presentationPublisherPublish", "presentationPublisherGetDiagnostics")) {
        if ($source -notmatch "function server\.$symbol\b") { $issues.Add("missing publisher API: $symbol") }
    }
    foreach ($route in @("ray.shieldImpact", "ray.effect", "projectile.spawn", "projectile.finish", "missile.spawn", "missile.finish", "craft.launch", "craft.recover")) {
        if ($source -notmatch [regex]::Escape('[' + '"' + $route + '"' + ']')) { $issues.Add("missing legacy route: $route") }
    }
    if ($source -notmatch 'presentationRuntime') { $issues.Add("init-only presentationRuntime switch missing") }
    if ($source -notmatch '(state\.mode|selectedMode)\s*==\s*"event-v1"') { $issues.Add("event-v1 branch missing") }
    if ($source -notmatch 'client\.receiveWeaponPresentationEventV1') { $issues.Add("event-v1 client transport missing") }
    if ($source -match 'function server\.presentationPublisherPublish[\s\S]*?GetStringParam\(') { $issues.Add("runtime mode must not be re-read inside publish hot path") }
    $clientSource = Get-Content -Raw -LiteralPath $eventRuntime
    foreach ($symbol in @("receiveWeaponPresentationEventV1", "presentationEventGetDiagnostics", "presentationEventDrain")) {
        if ($clientSource -notmatch "function client\.$symbol\b") { $issues.Add("missing client event API: $symbol") }
    }
    if ($clientSource -notmatch 'decode\(value\)') { $issues.Add("client DTO decode boundary missing") }
    $behaviourFiles = @(
        "script\weapon\server\behavior\raycast\control.lua",
        "script\weapon\server\behavior\projectile\manager.lua",
        "script\weapon\server\behavior\guided_projectile\runtime_state.lua",
        "script\weapon\server\behavior\strike_craft\control.lua",
        "script\weapon\server\behavior\charged_ray\control.lua"
    )
    foreach ($relative in $behaviourFiles) {
        $file = Join-Path $root $relative
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $issues.Add("missing integrated behaviour: $relative"); continue }
        $behaviour = Get-Content -Raw -LiteralPath $file
        if ($behaviour -notmatch 'presentationPublisherPublish') { $issues.Add("behaviour is not publisher-integrated: $relative") }
    }
}
if ($issues.Count -gt 0) { Write-Error ("Presentation Publisher check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Presentation Publisher contract passed: init switch, legacy routes, event-v1 receiver, and five behaviour integrations." -ForegroundColor Green
exit 0
