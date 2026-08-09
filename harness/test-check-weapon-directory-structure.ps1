# Self-test for check-weapon-directory-structure.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-weapon-directory-structure.ps1"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".weapon-directory-check-test-" + [Guid]::NewGuid().ToString("N"))
$mod = Join-Path $root "Content Mod 2"
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0
function Assert-True { param([bool]$Condition, [string]$Message); if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green } else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ } }
function Invoke-Checker { $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $mod 2>&1; return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") } }

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse
    $valid = Invoke-Checker; Assert-True ($valid.ExitCode -eq 0) "accepts the normalized weapon layout"
    $legacy = Join-Path $mod "script\weapon\client\common"
    New-Item -ItemType Directory -Path $legacy -Force | Out-Null
    $invalid = Invoke-Checker; Assert-True ($invalid.ExitCode -eq 1) "rejects a legacy common directory"
    Remove-Item -LiteralPath $legacy -Recurse -Force
    $legacyFile = Join-Path $mod "script\weapon\server\bootstrap.lua"
    $text = [IO.File]::ReadAllText($legacyFile)
    [IO.File]::WriteAllText($legacyFile, ($text + "`n#include ""slots/x/tachyon_lance/control.lua""`n"))
    $invalidInclude = Invoke-Checker; Assert-True ($invalidInclude.ExitCode -eq 1) "rejects a legacy slot include"
}
finally { if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" } elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force } }

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
