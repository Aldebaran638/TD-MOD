# Self-test for check-battlecruiser-definition.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-battlecruiser-definition.ps1"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".battlecruiser-check-test-" + [Guid]::NewGuid().ToString("N"))
$mod = Join-Path $root "Content Mod 2"
$powershellExe = (Get-Process -Id $PID).Path
$encoding = New-Object Text.UTF8Encoding($false)
$failures = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Host "[PASS] $Message" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures++ }
}

function Invoke-Checker {
    $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $mod 2>&1
    return @{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n") }
}

function Rewrite-Definition {
    param([string]$Before, [string]$After)
    $path = Join-Path $mod "script\data\ships\battlecruiser\battlecruiser.lua"
    $text = [IO.File]::ReadAllText($path)
    [IO.File]::WriteAllText($path, $text.Replace($Before, $After), $encoding)
}

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse

    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts the complete battlecruiser definition"

    Rewrite-Definition '    engineSound = {' '    obsoleteEngineSound = {'
    $engineSoundMissing = Invoke-Checker
    Assert-True ($engineSoundMissing.ExitCode -eq 1 -and $engineSoundMissing.Text -match 'missing required field: engineSound') "rejects a missing engine sound definition"
    Copy-Item -LiteralPath (Join-Path $source "script\data\ships\battlecruiser\battlecruiser.lua") -Destination (Join-Path $mod "script\data\ships\battlecruiser\battlecruiser.lua") -Force

    Rewrite-Definition 'shieldRadius = 7,' ''
    $missing = Invoke-Checker
    Assert-True ($missing.ExitCode -eq 1 -and $missing.Text -match 'missing required field: shieldRadius') "rejects a missing top-level field"
    Copy-Item -LiteralPath (Join-Path $source "script\data\ships\battlecruiser\battlecruiser.lua") -Destination (Join-Path $mod "script\data\ships\battlecruiser\battlecruiser.lua") -Force

    Rewrite-Definition 'shieldRadius = 7,' "shieldRadius = 7,`n    xSlotCount = 2,"
    $extra = Invoke-Checker
    Assert-True ($extra.ExitCode -eq 1 -and $extra.Text -match 'unknown field: xSlotCount') "rejects a removed top-level field"
    Copy-Item -LiteralPath (Join-Path $source "script\data\ships\battlecruiser\battlecruiser.lua") -Destination (Join-Path $mod "script\data\ships\battlecruiser\battlecruiser.lua") -Force

    Rewrite-Definition 'fov = 70.0,' ''
    $nestedMissing = Invoke-Checker
    Assert-True ($nestedMissing.ExitCode -eq 1 -and $nestedMissing.Text -match 'cameraProfile is missing required field: fov') "rejects a missing nested field"
    Copy-Item -LiteralPath (Join-Path $source "script\data\ships\battlecruiser\battlecruiser.lua") -Destination (Join-Path $mod "script\data\ships\battlecruiser\battlecruiser.lua") -Force

    Rewrite-Definition 'fov = 70.0,' "fov = 70.0,`n        obsoleteCameraField = 1.0,"
    $nestedExtra = Invoke-Checker
    Assert-True ($nestedExtra.ExitCode -eq 1 -and $nestedExtra.Text -match 'cameraProfile contains unknown field: obsoleteCameraField') "rejects an unknown nested field"
    Copy-Item -LiteralPath (Join-Path $source "script\data\ships\battlecruiser\battlecruiser.lua") -Destination (Join-Path $mod "script\data\ships\battlecruiser\battlecruiser.lua") -Force

    Rewrite-Definition '{ groupId = "xSlot", slotType = "X", count = 2 }' '{ groupId = "xSlot", slotType = "X" }'
    $groupMissing = Invoke-Checker
    Assert-True ($groupMissing.ExitCode -eq 1 -and $groupMissing.Text -match 'slot group is missing required field: count') "rejects an incomplete weapon group"
}
finally {
    if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" }
    elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
