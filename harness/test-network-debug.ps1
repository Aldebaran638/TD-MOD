# Static contract test for the low-overhead diagnostic counter API.

$ErrorActionPreference = "Stop"
$path = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "Content Mod 2\script\net\network_debug.lua"
$content = Get-Content -LiteralPath $path -Raw -Encoding utf8
$required = @(
    "diagnosticsEnabled = false",
    "function server.netDebugCount(",
    "function server.netDebugMeasure(",
    "function server.netDebugSetRuntimeCounts(",
    "function server.netDebugSnapshot()",
    "server.networkStats.counters = {}",
    "server.networkStats.timings = {}"
)
foreach ($text in $required) {
    if ($content.IndexOf($text, [StringComparison]::Ordinal) -lt 0) {
        throw "Missing diagnostic contract: $text"
    }
}
if ($content -notmatch "if server\.networkDebugConfig\.diagnosticsEnabled then") {
    throw "Diagnostic reset is not gated by diagnosticsEnabled."
}
Write-Host "[PASS] low-overhead diagnostic counter contract is present"
Write-Host "Self-test passed." -ForegroundColor Green
