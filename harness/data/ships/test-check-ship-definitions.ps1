# Self-test for check-ship-definitions.ps1.

param([switch]$KeepFixtures)

$checker = Join-Path $PSScriptRoot "check-ship-definitions.ps1"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$source = Join-Path $repositoryRoot "Content Mod 2"
$root = Join-Path $PSScriptRoot (".ship-definitions-test-" + [Guid]::NewGuid().ToString("N"))
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

function Rewrite-File {
    param([string]$RelativePath, [string]$Before, [string]$After)
    $path = Join-Path $mod $RelativePath
    $text = [IO.File]::ReadAllText($path)
    [IO.File]::WriteAllText($path, $text.Replace($Before, $After), $encoding)
}

function Restore-File {
    param([string]$RelativePath)
    Copy-Item -LiteralPath (Join-Path $source $RelativePath) -Destination (Join-Path $mod $RelativePath) -Force
}

try {
    Copy-Item -LiteralPath $source -Destination $mod -Recurse

    $valid = Invoke-Checker
    Assert-True ($valid.ExitCode -eq 0) "accepts all complete player and AI definitions"

    $aiPath = "script\data\ships\advanced_swarmer_missile\advanced_swarmer_missile.lua"
    Rewrite-File $aiPath '    controlMode = "ai",' ''
    $missingMode = Invoke-Checker
    Assert-True ($missingMode.ExitCode -eq 1 -and $missingMode.Text -match 'missing required field: controlMode') "rejects an AI definition without controlMode"
    Restore-File $aiPath

    $titanPath = "script\data\ships\titan\titan.lua"
    Rewrite-File $titanPath '    externalDamage = {' '    obsoleteDamage = {'
    $missingPlayerField = Invoke-Checker
    Assert-True ($missingPlayerField.ExitCode -eq 1 -and $missingPlayerField.Text -match 'missing required field: externalDamage') "rejects an incomplete player definition"
    Restore-File $titanPath

    Rewrite-File $titanPath '    hudProfile = {' '    obsoleteHudProfile = {'
    $missingHudProfile = Invoke-Checker
    Assert-True ($missingHudProfile.ExitCode -eq 1 -and $missingHudProfile.Text -match 'missing required field: hudProfile') "rejects a player definition without hudProfile"
    Restore-File $titanPath

    $craftPath = "script\data\ships\advanced_strike_craft\advanced_strike_craft.lua"
    Rewrite-File $craftPath '    externalDamage = {' "    cameraProfile = {},`n    externalDamage = {"
    $aiCrossField = Invoke-Checker
    Assert-True ($aiCrossField.ExitCode -eq 1 -and $aiCrossField.Text -match 'unknown field: cameraProfile') "rejects player-only fields on AI definitions"
    Restore-File $craftPath

    Rewrite-File $aiPath '    interceptorClass = "missile",' '    interceptorClass = "drone",'
    $invalidClass = Invoke-Checker
    Assert-True ($invalidClass.ExitCode -eq 1 -and $invalidClass.Text -match 'invalid interceptorClass') "rejects an invalid AI interceptor class"
    Restore-File $aiPath

    Rewrite-File $aiPath '    shieldRadius = 0.65,' "    shieldRadius = 0.65,`n    externalDamage = {},"
    $missileDamageProfile = Invoke-Checker
    Assert-True ($missileDamageProfile.ExitCode -eq 1 -and $missileDamageProfile.Text -match 'unknown field: externalDamage') "rejects unused external damage fields on guided missiles"
    Restore-File $aiPath

    $catalogPath = "script\data\ships\ship_catalog.lua"
    Rewrite-File $catalogPath '#include "titan/titan.lua"' ''
    $missingCatalogEntry = Invoke-Checker
    Assert-True ($missingCatalogEntry.ExitCode -eq 1 -and $missingCatalogEntry.Text -match 'unexpected include count') "rejects a catalog with a missing definition include"
    Restore-File $catalogPath

    Rewrite-File $catalogPath '#include "titan/titan.lua"' "#include `"titan/titan.lua`"`n#include `"titan/titan.lua`""
    $duplicateCatalogEntry = Invoke-Checker
    Assert-True ($duplicateCatalogEntry.ExitCode -eq 1 -and $duplicateCatalogEntry.Text -match 'unexpected include count') "rejects a catalog with duplicate includes"
    Restore-File $catalogPath

    $schemaPath = "script\data\ships\schema.lua"
    Rewrite-File $schemaPath 'function shipDefinitionIsAiControlled' 'function removedShipDefinitionIsAiControlled'
    $missingSchemaHelper = Invoke-Checker
    Assert-True ($missingSchemaHelper.ExitCode -eq 1 -and $missingSchemaHelper.Text -match 'schema.lua is missing shipDefinitionIsAiControlled') "rejects a schema without the AI helper"
}
finally {
    if ($KeepFixtures) { Write-Host "Fixtures kept at: $root" }
    elseif (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

if ($failures -gt 0) { exit 1 }
Write-Host "Self-test passed." -ForegroundColor Green
exit 0
