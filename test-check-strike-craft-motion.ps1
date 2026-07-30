# Self-test for check-strike-craft-motion.ps1.

param([switch]$KeepFixtures)

$ErrorActionPreference = "Stop"
$checker = Join-Path $PSScriptRoot "check-strike-craft-motion.ps1"
$sourceFile = Join-Path $PSScriptRoot "Content Mod 2\script\weapon\server\slots\h\gamma_strike_craft\flight_controller.lua"
$fixtureRoot = Join-Path $PSScriptRoot (".strike-motion-check-test-" + [Guid]::NewGuid().ToString("N"))
$fixtureMod = Join-Path $fixtureRoot "Content Mod 2"
$fixtureFile = Join-Path $fixtureMod "script\weapon\server\slots\h\gamma_strike_craft\flight_controller.lua"
$integrationFiles = @(
    "script\weapon\server\slots\h\gamma_strike_craft\control.lua",
    "script\data\weapons\h\gamma_strike_craft.lua",
    "script\weapon\client\slots\h\gamma_strike_craft\effects\craft_fx.lua",
    "prefabs\gammaStrikeCraft.xml"
)
$powershellExe = (Get-Process -Id $PID).Path
$failures = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "[PASS] $Message" -ForegroundColor Green
    }
    else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failures++
    }
}

function Write-Fixture {
    param([string]$Content)
    [IO.File]::WriteAllText(
        $fixtureFile,
        $Content,
        (New-Object Text.UTF8Encoding($false))
    )
}

function Invoke-Checker {
    $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $fixtureMod 2>&1
    return @{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

try {
    [IO.Directory]::CreateDirectory((Split-Path -Parent $fixtureFile)) | Out-Null
    foreach ($relativePath in $integrationFiles) {
        $sourcePath = Join-Path (Join-Path $PSScriptRoot "Content Mod 2") $relativePath
        $targetPath = Join-Path $fixtureMod $relativePath
        [IO.Directory]::CreateDirectory((Split-Path -Parent $targetPath)) | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath
    }
    $validSource = [IO.File]::ReadAllText($sourceFile)
    Write-Fixture $validSource

    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts the complete motion contract"

    Write-Fixture ($validSource + "`r`nExplosion(Vec(), 1.0)`r`n")
    $explosion = Invoke-Checker
    Assert-True ($explosion.ExitCode -eq 1) "rejects explosions in movement code"
    Assert-True ($explosion.Output -match "must not create explosions") "reports movement/lifecycle separation"

    Write-Fixture $validSource.Replace(
        "QueryRejectBody(ownerBody)",
        "-- missing own-body filter"
    )
    $filter = Invoke-Checker
    Assert-True ($filter.ExitCode -eq 1) "rejects a raycast wrapper without self filtering"
    Assert-True ($filter.Output -match "filter-resetting query wrapper") "reports query filter ordering"

    Write-Fixture $validSource.Replace(
        "{ yaw = 60.0, pitch = 8.0 },",
        "{ yaw = 60.0, pitch = 8.0 },`r`n    { yaw = 75.0, pitch = 20.0 },"
    )
    $candidates = Invoke-Checker
    Assert-True ($candidates.ExitCode -eq 1) "rejects more than eight planner candidates"
    Assert-True ($candidates.Output -match "between 1 and 8") "reports candidate budget overflow"

    Write-Fixture $validSource.Replace(
        '"emergencyDuration", 0.70',
        '"emergencyDuration", 2.50'
    )
    $emergency = Invoke-Checker
    Assert-True ($emergency.ExitCode -eq 1) "rejects an unbounded emergency window"
    Assert-True ($emergency.Output -match "0.5-1.2") "reports the emergency duration contract"

    Write-Fixture $validSource.Replace(
        "craft.plannerRemain = 0.20",
        "craft.plannerRemain = 0.05"
    )
    $budget = Invoke-Checker
    Assert-True ($budget.ExitCode -eq 1) "rejects an excessive complex-query budget"
    Assert-True ($budget.Output -match "exceeds 80") "reports calculated query pressure"
}
finally {
    if ($KeepFixtures) {
        Write-Host "Fixtures kept at: $fixtureRoot"
    }
    elseif (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

if ($failures -gt 0) {
    Write-Host "Self-test failed: $failures assertion(s)." -ForegroundColor Red
    exit 1
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
