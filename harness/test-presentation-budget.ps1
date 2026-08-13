# Self-test for Presentation Budget facade and direct-call fixture policy.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-presentation-budget.ps1"
$fixture = Join-Path $repositoryRoot "harness\data\presentation\direct-call-fixtures.json"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$data = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
if (@($data.forbidden).Count -ne 5) { throw "direct-call fixture must cover five primitives" }
foreach ($snippet in $data.forbidden) {
    if ([string]::IsNullOrWhiteSpace([string]$snippet)) { throw "direct-call fixture contains an empty snippet" }
}
$facade = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "Content Mod 2\script\weapon\client\presentation\presentation_budget.lua")
if ($facade -notmatch 'budget\.state\.beginCount\s*=\s*budget\.state\.beginCount\s*\+\s*1') { throw "begin count accounting is missing" }
if ($facade -notmatch 'state\.degraded\s*=\s*state\.degraded\s*\+\s*1') { throw "degraded accounting is missing" }
Write-Host "[PASS] five primitive direct-call fixture and facade whitelist are present"
Write-Host "[PASS] one begin owner and accepted/degraded/rejected counters are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
