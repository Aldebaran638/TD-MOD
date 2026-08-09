# Self-test for check-weapon-rendering.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-weapon-rendering.ps1"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".weapon-rendering-check-test-" + [Guid]::NewGuid().ToString("N"))
$mod = Join-Path $root "Content Mod 2"
$powershellExe = (Get-Process -Id $PID).Path
$encoding = New-Object Text.UTF8Encoding($false)
$failures = 0

function Assert-True { param([bool]$Condition, [string]$Message); if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ } }
function Invoke-Checker { $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $mod 2>&1; return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") } }

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse
    $valid = Invoke-Checker; Assert-True ($valid.ExitCode -eq 0) "accepts the stage-organized client effect layout"
    Remove-Item -LiteralPath (Join-Path $mod "script\weapon\client\presentation\visual\runtime\registry\palette_profile_registry.lua") -Force
    $missing = Invoke-Checker; Assert-True ($missing.ExitCode -eq 1) "rejects a missing palette registry"
    Copy-Item -LiteralPath (Join-Path $source "script\weapon\client\presentation\visual\runtime\registry\palette_profile_registry.lua") -Destination (Join-Path $mod "script\weapon\client\presentation\visual\runtime\registry\palette_profile_registry.lua") -Force
    $old = Join-Path $mod "script\weapon\client\slots\x\tachyon_lance\effects"
    New-Item -ItemType Directory -Path $old -Force | Out-Null
    $obsolete = Invoke-Checker; Assert-True ($obsolete.ExitCode -eq 1) "rejects an obsolete representative-weapon effect directory"
    Remove-Item -LiteralPath $old -Recurse -Force
    $gamma = Join-Path $mod "script\weapon\client\presentation\visual\phase\beam\gamma.lua"
    [IO.File]::WriteAllText($gamma, ([IO.File]::ReadAllText($gamma) + "`nlocal broken = weaponType == `"tachyonLance`"`n"), $encoding)
    $weaponTypeBranch = Invoke-Checker; Assert-True ($weaponTypeBranch.ExitCode -eq 1) "rejects rendering branches selected by weaponType"
}
finally { if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" } elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
