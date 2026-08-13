# Self-tests for check-entry-closures.ps1.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$checker = Join-Path $repositoryRoot "harness\check-entry-closures.ps1"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("entry-closure-fixtures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Write-FixtureFile([string]$relativePath, [string]$content) {
    $path = Join-Path $tempRoot $relativePath.Replace("/", "\")
    $directory = Split-Path -Parent $path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    [IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding($false)))
}

function Run-Fixture([string]$name, [string]$mainContent, [string]$xmlContent, [hashtable]$extraFiles) {
    $fixtureRoot = Join-Path $tempRoot $name
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $fixtureRoot "main.lua"), $mainContent, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $fixtureRoot "main.xml"), $xmlContent, (New-Object Text.UTF8Encoding($false)))
    foreach ($key in $extraFiles.Keys) {
        $path = Join-Path $fixtureRoot $key.Replace("/", "\")
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [IO.File]::WriteAllText($path, $extraFiles[$key], (New-Object Text.UTF8Encoding($false)))
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $checker -Path $fixtureRoot 2>&1 | Out-String | Out-Null
    return $LASTEXITCODE
}

try {
    $validXml = '<scene><script file="main.lua"/><script file="MOD/prefabs/test.xml"/></scene>'
    $validPrefab = '<prefab><script file="MOD/prefab.lua"/></prefab>'
    $validExit = Run-Fixture "valid" '#include "child.lua"' $validXml @{
        "child.lua" = "-- valid"
        "prefabs/test.xml" = $validPrefab
        "prefab.lua" = "-- valid prefab entry"
        "shipMain.lua" = "-- explicit ship entry"
    }
    if ($validExit -ne 0) { throw "valid fixture was rejected" }
    Write-Host "[PASS] accepts valid XML/Lua entry closure"

    $missingRootExit = Run-Fixture "missing-root-include" '#include "missing.lua"' '<scene><script file="main.lua"/></scene>' @{}
    if ($missingRootExit -eq 0) { throw "missing root include was accepted" }
    Write-Host "[PASS] rejects missing root include"

    $missingPrefabExit = Run-Fixture "missing-prefab-script" '-- valid' '<scene><script file="MOD/missing-prefab.lua"/></scene>' @{}
    if ($missingPrefabExit -eq 0) { throw "missing prefab script was accepted" }
    Write-Host "[PASS] rejects missing prefab script"

    $missingCatalogExit = Run-Fixture "missing-generated-catalog" '#include "generated/catalog.lua"' '<scene><script file="main.lua"/></scene>' @{}
    if ($missingCatalogExit -eq 0) { throw "missing generated catalog was accepted" }
    Write-Host "[PASS] rejects missing generated catalog include"

    $cycleExit = Run-Fixture "include-cycle" '#include "a.lua"' '<scene><script file="main.lua"/></scene>' @{
        "a.lua" = '#include "b.lua"'
        "b.lua" = '#include "a.lua"'
    }
    if ($cycleExit -eq 0) { throw "include cycle was accepted" }
    Write-Host "[PASS] rejects include cycle"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
