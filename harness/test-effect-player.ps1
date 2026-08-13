# Self-test for EffectPlayer v1 static contract.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-effect-player.ps1"
$module = Join-Path $repositoryRoot "Content Mod 2\script\weapon\client\presentation\effect_player.lua"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path (Join-Path $repositoryRoot "Content Mod 2") 2>$null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$source = Get-Content -Raw -LiteralPath $module
if ($source -notmatch 'local index = state\.free\[#state\.free\]') { throw "free-list allocation is missing" }
if ($source -notmatch 'state\.activeIndices\[state\.activeCount\] = index') { throw "dense active storage is missing" }
if ($source -notmatch 'instance\.handle\.generation ~= math\.floor\(handle\.generation\)') { throw "stale generation rejection is missing" }
Write-Host "[PASS] play/update/stop/destroy and generation-handle stale rejection are present"
Write-Host "[PASS] fixed capacity, dense active indices, owner/anchor policy and resource cache are present"
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
