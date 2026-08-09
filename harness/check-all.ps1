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
    Invoke-Harness "harness/check-lua.ps1" ".\Content Mod 2\script"
    Invoke-Harness "harness/check-teardown-api.ps1" ".\Content Mod 2\script"
    Invoke-Harness "harness/check-xml.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-charged-weapons.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-noncharged-lasers.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-ballistic-weapons.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/check-weapon-rendering.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/data/weapons/check-explicit-weapon-definitions.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/data/components/check-explicit-component-definitions.ps1" ".\Content Mod 2"
    Invoke-Harness "harness/data/ships/check-ship-definitions.ps1" ".\Content Mod 2"

    Invoke-Harness "harness/test-check-lua.ps1"
    Invoke-Harness "harness/test-check-teardown-api.ps1"
    Invoke-Harness "harness/test-check-xml.ps1"
    Invoke-Harness "harness/test-check-charged-weapons.ps1"
    Invoke-Harness "harness/test-check-noncharged-lasers.ps1"
    Invoke-Harness "harness/test-check-ballistic-weapons.ps1"
    Invoke-Harness "harness/test-check-weapon-rendering.ps1"
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
