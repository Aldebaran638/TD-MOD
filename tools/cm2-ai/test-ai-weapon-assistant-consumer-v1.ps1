$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$installer = Join-Path $PSScriptRoot "install-ai-weapon-assistant-consumer-v1.ps1"
$consumer = Join-Path $root "_AI Test Consumer AI Weapon V1"
$trace = Join-Path $root "docs\candidates\ai-weapon-assistant-v1.consumer-trace.json"

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("AI Weapon Consumer regression failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-Install([string]$tracePath) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -TracePath $tracePath *> $null
    return [int]$LASTEXITCODE
}

Assert-True ((Invoke-Install $trace) -eq 0) "data-only AI package stages into independent Consumer"
$first = Get-Content -Raw -LiteralPath $trace | ConvertFrom-Json
$artifactPath = Join-Path $consumer "packages\cm2.ai.weapon.assistant\candidate.artifact.json"
$mainPath = Join-Path $consumer "main.xml"
$hostPath = Join-Path $consumer "script\testing\ai_weapon\consumer_host.lua"
Assert-True ([string]$first.result -eq "pass" -and [string]$first.runtimeEntrypoint -eq "data-only") "consumer trace is data-only and passing"
Assert-True ([string]$first.validOperation -eq "accepted:Weapon-Projectile-Effect" -and [string]$first.invalidOperation -eq "rejected:ExecuteLua") "public capability accepts Weapon/Projectile/Effect and rejects Lua"
Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash.ToLowerInvariant() -eq [string]$first.packageHash) "installed candidate artifact hash is exact"
Assert-True ((Get-Content -Raw -LiteralPath $mainPath).Contains([string]$first.packageHash)) "Consumer XML carries the installed package hash"
Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $consumer "packages") -Recurse -File -Filter "*.lua").Count -eq 0) "installed AI package contains no Runtime Lua"
$hostSource = Get-Content -Raw -LiteralPath $hostPath
foreach ($forbidden in @("Content Mod 2", "Global Mod", "include(", "dofile(", "loadfile(", "ServerCall(")) {
    Assert-True (-not $hostSource.Contains($forbidden)) ("Consumer host has no private/runtime reference: " + $forbidden)
}
$secondTrace = Join-Path ([IO.Path]::GetTempPath()) ("cm2-ai-consumer-" + [Guid]::NewGuid().ToString("N") + ".json")
try {
    Assert-True ((Invoke-Install $secondTrace) -eq 0) "second independent Consumer staging passes"
    $second = Get-Content -Raw -LiteralPath $secondTrace | ConvertFrom-Json
    Assert-True ([string]$first.packageHash -eq [string]$second.packageHash) "independent Consumer package hash is deterministic"
}
finally {
    if (Test-Path -LiteralPath $secondTrace) { Remove-Item -LiteralPath $secondTrace -Force -ErrorAction SilentlyContinue }
}
Write-Host "AI Weapon independent Consumer regression passed." -ForegroundColor Green
exit 0
