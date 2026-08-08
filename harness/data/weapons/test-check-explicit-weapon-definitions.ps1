# Self-test for check-explicit-weapon-definitions.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-explicit-weapon-definitions.ps1"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".explicit-weapon-check-test-" + [Guid]::NewGuid().ToString("N"))
$mod = Join-Path $root "Content Mod 2"
$powershellExe = (Get-Process -Id $PID).Path
$encoding = New-Object Text.UTF8Encoding($false)
$failures = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failures++
    }
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
    param([string]$Slot)
    $relative = "script\data\weapons\$Slot\stellaris.lua"
    Copy-Item -LiteralPath (Join-Path $source $relative) -Destination (Join-Path $mod $relative) -Force
}

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse
    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts separately defined slot weapons"

    $small = Join-Path $mod "script\data\weapons\s\stellaris.lua"
    Rewrite $small 'weaponDefineRay({' "for _, definition in ipairs({}) do`nweaponDefineRay({"
    $loop = Invoke-Checker
    Assert-True ($loop.ExitCode -eq 1 -and $loop.Text -match 'uses a loop') "rejects loop-generated definitions"
    Restore-Slot "s"

    Rewrite $small 'weaponDefineRay({' 'weaponDefineLaser({'
    $unsupported = Invoke-Checker
    Assert-True ($unsupported.ExitCode -eq 1 -and $unsupported.Text -match 'unsupported function') "rejects unsupported definition functions"
    Restore-Slot "s"

    Rewrite $small '-- Unified S slot weapon definitions.' "-- Unified S slot weapon definitions.`nlocal weaponTiers = {}"
    $table = Invoke-Checker
    Assert-True ($table.ExitCode -eq 1 -and $table.Text -match 'top-level structure') "rejects batch definition tables"
    Restore-Slot "s"

    Rewrite $small 'weaponType = "smallPsionicDisruptor",' "weaponType = `"smallPsionicDisruptor`",`n    weaponType = `"duplicateWeapon`","
    $multipleIds = Invoke-Checker
    Assert-True ($multipleIds.ExitCode -eq 1 -and $multipleIds.Text -match 'exactly one literal weaponType') "rejects multiple weapons in one definition"
    Restore-Slot "s"

    $titan = Join-Path $mod "script\data\weapons\t\stellaris.lua"
    [IO.File]::WriteAllText($titan, '-- weaponDefineRay({ weaponType = "commented", slotTypes = { "T" } })', $encoding)
    $commented = Invoke-Checker
    Assert-True ($commented.ExitCode -eq 1 -and $commented.Text -match 'has no direct weapon definitions') "ignores definitions inside comments"
    Restore-Slot "t"

    Rewrite $small 'slotTypes = { "S" },' 'slotTypes = { "M" },'
    $wrongSlot = Invoke-Checker
    Assert-True ($wrongSlot.ExitCode -eq 1 -and $wrongSlot.Text -match 'must declare only slotTypes') "rejects definitions stored under the wrong slot"
    Restore-Slot "s"

    $extra = Join-Path $mod "script\data\weapons\s\extra.lua"
    [IO.File]::WriteAllText($extra, 'weaponDefineRay({ weaponType = "extra", slotTypes = { "S" } })', $encoding)
    $extraFile = Invoke-Checker
    Assert-True ($extraFile.ExitCode -eq 1 -and $extraFile.Text -match 'extra Lua definition file') "rejects extra per-slot definition files"
}
finally {
    if ($KeepFixtures) {
        Write-Host "Fixtures kept at: $root"
    } elseif (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
