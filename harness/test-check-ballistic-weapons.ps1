# Self-test for check-ballistic-weapons.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-ballistic-weapons.ps1"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".ballistic-weapon-check-test-" + [Guid]::NewGuid().ToString("N"))
$mod = Join-Path $root "Content Mod 2"
$powershellExe = (Get-Process -Id $PID).Path
$encoding = New-Object Text.UTF8Encoding($false)
$failures = 0

function Assert-True { param([bool]$Condition, [string]$Message); if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ } }
function Invoke-Checker { $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $mod 2>&1; return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") } }
function Rewrite { param([string]$Path, [string]$Before, [string]$After); $text = [IO.File]::ReadAllText($Path); [IO.File]::WriteAllText($Path, $text.Replace($Before, $After), $encoding) }

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse
    $valid = Invoke-Checker; Assert-True ($valid.ExitCode -eq 0) "accepts normalized ballistic weapon contracts"
    $kinetic = Join-Path $mod "script\data\weapons\l\kinetic_artillery.lua"
    Rewrite $kinetic 'impactFxProfile = "kineticArtillery",' ''
    $missing = Invoke-Checker; Assert-True ($missing.ExitCode -eq 1) "rejects missing impactFxProfile"
    Copy-Item -LiteralPath (Join-Path $source "script\data\weapons\l\kinetic_artillery.lua") -Destination $kinetic -Force
    $generated = Join-Path $mod "script\data\weapons\stellaris_generated_4_4_6.lua"
    Rewrite $generated 'projectileRadius = item.projectileRadius,' ''
    $propagation = Invoke-Checker; Assert-True ($propagation.ExitCode -eq 1) "rejects missing generated projectile radius propagation"
    Copy-Item -LiteralPath (Join-Path $source "script\data\weapons\stellaris_generated_4_4_6.lua") -Destination $generated -Force
    Rewrite $generated 'impactFxProfile = item.impactFxProfile,' 'impactFxProfile = item.brokenImpactFxProfile,'
    $dispatch = Invoke-Checker; Assert-True ($dispatch.ExitCode -eq 1) "rejects broken generated impact dispatch"
}
finally { if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" } elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
