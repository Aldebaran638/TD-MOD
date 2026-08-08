# Self-test for check-charged-weapons.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-charged-weapons.ps1"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".charged-weapon-check-test-" + [Guid]::NewGuid().ToString("N"))
$mod = Join-Path $root "Content Mod 2"
$powershellExe = (Get-Process -Id $PID).Path
$encoding = New-Object Text.UTF8Encoding($false)
$failures = 0

function Assert-True { param([bool]$Condition, [string]$Message); if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ } }
function Invoke-Checker { $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $mod 2>&1; return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") } }
function Rewrite { param([string]$Path, [string]$Before, [string]$After); $text = [IO.File]::ReadAllText($Path); [IO.File]::WriteAllText($Path, $text.Replace($Before, $After), $encoding) }

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse
    $valid = Invoke-Checker; Assert-True ($valid.ExitCode -eq 0) "accepts charged weapon contracts"
    $tachyon = Join-Path $mod "script\data\weapons\x\stellaris.lua"
    Rewrite $tachyon 'chargeFxProfile = "tachyonLance",' ''
    $missing = Invoke-Checker; Assert-True ($missing.ExitCode -eq 1) "rejects missing chargeFxProfile"
    Copy-Item -LiteralPath (Join-Path $source "script\data\weapons\x\stellaris.lua") -Destination $tachyon -Force
    $generated = $tachyon
    Rewrite $generated 'controllerType = "chargedRay",' ''
    $propagation = Invoke-Checker; Assert-True ($propagation.ExitCode -eq 1) "rejects missing charged controller"
}
finally { if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" } elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
