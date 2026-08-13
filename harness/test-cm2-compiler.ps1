# Self-tests for the deterministic Definition Compiler MVP.

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$compiler = Join-Path $repositoryRoot "tools\cm2-compiler\compile-definitions.ps1"
$validInput = Join-Path $repositoryRoot "harness\data\compiler\valid"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-compiler-fixtures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Run-Compiler([string]$inputPath, [string]$outputPath) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $compiler -InputPath $inputPath -OutputPath $outputPath 2>$null | Out-String | Out-Null
        return $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
}

function Read-BytesText([string]$path) {
    return [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($path))
}

function Copy-Valid([string]$name) {
    $destination = Join-Path $tempRoot $name
    Copy-Item -LiteralPath $validInput -Destination $destination -Recurse
    return $destination
}

try {
    $one = Copy-Valid "deterministic-one"
    $two = Copy-Valid "deterministic-two"
    $outputOne = Join-Path $one "catalog.lua"
    $outputTwo = Join-Path $two "catalog.lua"
    if ((Run-Compiler $one $outputOne) -ne 0) { throw "first valid compilation failed" }
    if ((Run-Compiler $two $outputTwo) -ne 0) { throw "second valid compilation failed" }
    if ((Read-BytesText $outputOne) -cne (Read-BytesText $outputTwo)) { throw "same input did not produce byte-identical catalogs" }
    $catalogText = Read-BytesText $outputOne
    if ($catalogText -notmatch '^-- CM2 GENERATED FILE; DO NOT EDIT\.' -or $catalogText -match 'editor|ai|build') { throw "generated catalog header or runtime-only projection is invalid" }
    if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($outputOne, ".manifest.json")))) { throw "manifest was not emitted" }
    if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($outputOne, ".diagnostics.md")))) { throw "human diagnostics were not emitted" }
    Write-Host "[PASS] deterministic byte-identical catalog, manifest, and human diagnostics"

    $badReference = Copy-Valid "bad-reference"
    $badWeaponPath = Join-Path $badReference "weapon-ray.json"
    $badWeapon = Get-Content -Raw -LiteralPath $badWeaponPath | ConvertFrom-Json
    $badWeapon.runtime.effectId = "cm2:missing.effect"
    $badWeapon | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $badWeaponPath -Encoding utf8
    $badOutput = Join-Path $badReference "catalog.lua"
    "previous-valid-catalog" | Set-Content -LiteralPath $badOutput -Encoding utf8
    if ((Run-Compiler $badReference $badOutput) -eq 0) { throw "broken reference was accepted" }
    if ((Read-BytesText $badOutput).Trim() -cne "previous-valid-catalog") { throw "failed build overwrote previous catalog" }
    $badReport = Get-Content -Raw -LiteralPath ([IO.Path]::ChangeExtension($badOutput, ".report.json")) | ConvertFrom-Json
    if (@($badReport.errors | Where-Object code -eq "broken-reference").Count -eq 0) { throw "broken reference diagnostic missing" }
    if ((Get-Content -Raw -LiteralPath ([IO.Path]::ChangeExtension($badOutput, ".diagnostics.md"))) -notmatch "Result: FAIL") { throw "human failure diagnostic missing" }
    Write-Host "[PASS] broken reference fails before publish and preserves previous catalog"

    $duplicate = Copy-Valid "duplicate-id"
    Copy-Item -LiteralPath (Join-Path $duplicate "effect-ray.json") -Destination (Join-Path $duplicate "effect-ray-copy.json")
    $duplicateOutput = Join-Path $duplicate "catalog.lua"
    if ((Run-Compiler $duplicate $duplicateOutput) -eq 0) { throw "duplicate ID was accepted" }
    Write-Host "[PASS] duplicate ID fails before publish"

    $future = Copy-Valid "future-version"
    $futurePath = Join-Path $future "effect-ray.json"
    $futureDocument = Get-Content -Raw -LiteralPath $futurePath | ConvertFrom-Json
    $futureDocument.schemaVersion = "cm2.effect/2"
    $futureDocument | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $futurePath -Encoding utf8
    if ((Run-Compiler $future (Join-Path $future "catalog.lua")) -eq 0) { throw "future schema version was accepted" }
    Write-Host "[PASS] future schema version fails before publish"

    $missingResource = Copy-Valid "missing-resource"
    $resourcePath = Join-Path $missingResource "resources.json"
    $resourceDocument = Get-Content -Raw -LiteralPath $resourcePath | ConvertFrom-Json
    $resourceDocument.resources[0].path = "assets/not-found.asset"
    $resourceDocument | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resourcePath -Encoding utf8
    if ((Run-Compiler $missingResource (Join-Path $missingResource "catalog.lua")) -eq 0) { throw "missing resource was accepted" }
    Write-Host "[PASS] missing resource fails before publish"

    Write-Host "Self-test passed." -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
