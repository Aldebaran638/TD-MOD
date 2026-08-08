# Self-test for check-explicit-component-definitions.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-explicit-component-definitions.ps1"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".explicit-component-check-test-" + [Guid]::NewGuid().ToString("N"))
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

function Rewrite {
    param([string]$Path, [string]$Before, [string]$After)
    $text = [IO.File]::ReadAllText($Path)
    [IO.File]::WriteAllText($Path, $text.Replace($Before, $After), $encoding)
}

function Restore-Slot {
    param([string]$Relative)
    Copy-Item -LiteralPath (Join-Path $source $Relative) -Destination (Join-Path $mod $Relative) -Force
}

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse
    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts separately defined component slots"

    $auxiliary = Join-Path $mod "script\data\components\defense\a\stellaris.lua"
    Rewrite $auxiliary 'shipComponentDefine({' "for _, definition in ipairs({}) do`nshipComponentDefine({"
    $loop = Invoke-Checker
    Assert-True ($loop.ExitCode -eq 1 -and $loop.Text -match 'uses a loop') "rejects loop-generated definitions"
    Restore-Slot "script\data\components\defense\a\stellaris.lua"

    Rewrite $auxiliary 'shipComponentDefine({' 'shipComponentBatchDefine({'
    $unsupported = Invoke-Checker
    Assert-True ($unsupported.ExitCode -eq 1 -and $unsupported.Text -match 'unsupported function') "rejects unsupported definition functions"
    Restore-Slot "script\data\components\defense\a\stellaris.lua"

    Rewrite $auxiliary 'componentId = "advancedAfterburners"' 'componentId = ""'
    $missingId = Invoke-Checker
    Assert-True ($missingId.ExitCode -eq 1 -and $missingId.Text -match 'literal componentId') "rejects missing component IDs"
    Restore-Slot "script\data\components\defense\a\stellaris.lua"

    Rewrite $auxiliary 'slotType = "auxiliary"' 'slotType = "reactor"'
    $wrongSlot = Invoke-Checker
    Assert-True ($wrongSlot.ExitCode -eq 1 -and $wrongSlot.Text -match 'must declare slotType') "rejects definitions stored under the wrong slot"
    Restore-Slot "script\data\components\defense\a\stellaris.lua"

    Rewrite $auxiliary 'componentId = "shieldCapacitor"' 'componentId = "advancedAfterburners"'
    $duplicate = Invoke-Checker
    Assert-True ($duplicate.ExitCode -eq 1 -and $duplicate.Text -match 'defined more than once') "rejects duplicate component IDs"
    Restore-Slot "script\data\components\defense\a\stellaris.lua"

    $extra = Join-Path $mod "script\data\components\defense\a\extra.lua"
    [IO.File]::WriteAllText($extra, 'shipComponentDefine({ componentId = "extra", slotType = "auxiliary" })', $encoding)
    $extraFile = Invoke-Checker
    Assert-True ($extraFile.ExitCode -eq 1 -and $extraFile.Text -match 'extra Lua definition file') "rejects extra per-slot definition files"
    Remove-Item -LiteralPath $extra -Force

    $catalog = Join-Path $mod "script\data\components\component_catalog.lua"
    Rewrite $catalog 'shipComponentGetSlotPool' 'legacyComponentGetSlotPool'
    $missingPool = Invoke-Checker
    Assert-True ($missingPool.ExitCode -eq 1 -and $missingPool.Text -match 'missing automatic slot pool') "rejects a missing automatic slot pool"
}
finally {
    if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" }
    elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
