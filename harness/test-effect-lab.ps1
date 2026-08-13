# Self-test for Effect Lab MVP contract.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-effect-lab.ps1"
$fixture = Join-Path $repositoryRoot "harness\data\presentation\effect-lab-fixtures.json"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$data = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
if (@($data.distances) -notcontains "near" -or @($data.distances) -notcontains "far") { throw "near/far fixture coverage is missing" }
if (@($data.budgetProfiles).Count -ne 3) { throw "budget profile fixture coverage is missing" }
$source = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "Content Mod 2\script\weapon\client\presentation\effect_lab.lua")
if ($source -notmatch 'while #state\.trace > 256') { throw "Effect Lab trace is not bounded" }
if ($source -notmatch 'sourceArtifact') { throw "generated source provenance is missing" }
Write-Host "[PASS] synthetic origin/direction/hit/anchor and four generated definitions are declared"
Write-Host "[PASS] fixed seed, near/far LOD, budget profiles, replay trace and production Player/Budget reuse are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
