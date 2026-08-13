# Runs the complete project Harness suite. Stops at the first failure.

param(
    [switch]$IncludeGlobal
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$powershellExe = (Get-Process -Id $PID).Path

function Invoke-Harness {
    param([string]$RelativeScript, [string]$TargetPath = "")

    $scriptPath = Join-Path $repositoryRoot $RelativeScript
    $displayArguments = ""
    if ($TargetPath -ne "") { $displayArguments = "-Path " + $TargetPath }
    Write-Host ("==> " + $RelativeScript + " " + $displayArguments) -ForegroundColor Cyan
    # Self-tests use exit; isolate every check so one script cannot end this runner.
    if ($TargetPath -ne "") {
        & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Path $TargetPath
    } else {
        & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Harness failed: $RelativeScript"
    }
}

Push-Location $repositoryRoot
try {
    Invoke-Harness "harness/check-entry-closures.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-source-of-truth.ps1" "."
    Invoke-Harness "harness/check-id-coordinate-contract.ps1" "."
    Invoke-Harness "harness/check-schema-v1.ps1" "."
    Invoke-Harness "harness/check-presentation-event-v1.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-presentation-publisher.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-presentation-event-ring.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-effect-player.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-presentation-budget.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-presentation-slices.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-presentation-migration.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-effect-lab.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-effect-runtime-authority.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-effect-profile-source.ps1" "."
    Invoke-Harness "harness/check-weapon-projectile-catalog.ps1" "."
    Invoke-Harness "harness/check-vehicle-component-catalog.ps1" "."
    Invoke-Harness "harness/check-loadout-contract-v1.ps1" "."
    Invoke-Harness "harness/check-generated-catalog-manifest-v1.ps1" "."
    Invoke-Harness "harness/check-catalog-authority-v1.ps1" "."
    Invoke-Harness "harness/check-shadow-catalog.ps1" "."
    Invoke-Harness "harness/check-lua.ps1" ".\Content Mod 2\script"
    Invoke-Harness "harness/check-teardown-api.ps1" ".\Content Mod 2\script"
    Invoke-Harness "harness/check-xml.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-charged-weapons.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-noncharged-lasers.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-ballistic-weapons.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-weapon-rendering.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-weapon-directory-structure.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/data/weapons/check-explicit-weapon-definitions.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/data/components/check-explicit-component-definitions.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/data/ships/check-ship-definitions.ps1" ".\Content Mod 2"

    Invoke-Harness "harness/test-check-entry-closures.ps1"
    Invoke-Harness "harness/test-check-source-of-truth.ps1"
    Invoke-Harness "harness/test-check-id-coordinate-contract.ps1"
    Invoke-Harness "harness/test-check-schema-v1.ps1"
    Invoke-Harness "harness/test-presentation-event-v1.ps1"
    Invoke-Harness "harness/test-presentation-publisher.ps1"
    Invoke-Harness "harness/test-presentation-event-ring.ps1"
    Invoke-Harness "harness/test-effect-player.ps1"
    Invoke-Harness "harness/test-presentation-budget.ps1"
    Invoke-Harness "harness/test-presentation-slices.ps1"
    Invoke-Harness "harness/test-presentation-migration.ps1"
    Invoke-Harness "harness/test-effect-lab.ps1"
    Invoke-Harness "harness/test-effect-runtime-authority.ps1"
    Invoke-Harness "harness/test-effect-profile-source.ps1"
    Invoke-Harness "harness/test-weapon-projectile-catalog.ps1"
    Invoke-Harness "harness/test-check-vehicle-component-catalog.ps1"
    Invoke-Harness "harness/test-loadout-contract-v1.ps1"
    Invoke-Harness "harness/test-check-generated-catalog-manifest-v1.ps1"
    Invoke-Harness "harness/test-catalog-authority-v1.ps1"
    Invoke-Harness "harness/test-shadow-catalog.ps1"
    Invoke-Harness "harness/test-cm2-compiler.ps1"
    Invoke-Harness "harness/test-semantic-snapshot.ps1"
    Invoke-Harness "harness/test-vertical-slices.ps1"
    Invoke-Harness "harness/test-network-debug.ps1"
    Invoke-Harness "harness/test-check-lua.ps1"
    Invoke-Harness "harness/test-check-teardown-api.ps1"
    Invoke-Harness "harness/test-check-xml.ps1"
    Invoke-Harness "harness/test-check-charged-weapons.ps1"
    Invoke-Harness "harness/test-check-noncharged-lasers.ps1"
    Invoke-Harness "harness/test-check-ballistic-weapons.ps1"
    Invoke-Harness "harness/test-check-weapon-rendering.ps1"
    Invoke-Harness "harness/test-check-weapon-directory-structure.ps1"
    Invoke-Harness "harness/data/weapons/test-check-explicit-weapon-definitions.ps1"
    Invoke-Harness "harness/data/components/test-check-explicit-component-definitions.ps1"
    Invoke-Harness "harness/data/ships/test-check-ship-definitions.ps1"

    if ($IncludeGlobal) {
        Invoke-Harness "harness/check-lua.ps1" ".\Global Mod\script"
        Invoke-Harness "harness/check-teardown-api.ps1" ".\Global Mod\script"
    }

    Write-Host "All Harness checks passed." -ForegroundColor Green
}
finally {
    Pop-Location
}
