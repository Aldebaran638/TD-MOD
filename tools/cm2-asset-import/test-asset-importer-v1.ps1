# Self-test for Asset Importer / AssetManifest v1.

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run-asset-importer-v1.ps1"
$fixture = Join-Path $PSScriptRoot "..\..\docs\candidates\asset-importer-v1.fixture.json"
$voxPath = Join-Path $PSScriptRoot "..\..\Content Mod 2\vox\gammaStrikeCraftTest.vox"
$validateVox = "C:\Users\XKWL\.codex\skills\build-teardown-vox-models\scripts\validate-vox.ps1"
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ("Asset Importer self-test failed: " + $message) }
    Write-Host ("[PASS] " + $message) -ForegroundColor Green
}
function Invoke-ExpectedFailure([string]$invalidFixture, [string]$label) {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -FixturePath $invalidFixture 2>$null *> $null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    Assert-True ($exitCode -ne 0) $label
}
function Write-Fixture([object]$document, [string]$path) { [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 60), $utf8) }
function Find-Ascii([byte[]]$bytes, [string]$text) {
    $needle = [Text.Encoding]::ASCII.GetBytes($text)
    for ($index = 0; $index -le ($bytes.Length - $needle.Length); $index++) {
        $match = $true
        for ($offset = 0; $offset -lt $needle.Length; $offset++) { if ($bytes[$index + $offset] -ne $needle[$offset]) { $match = $false; break } }
        if ($match) { return $index }
    }
    return -1
}
function Copy-Bytes([byte[]]$source, [int]$length) {
    $result = New-Object byte[] $length
    [Array]::Copy($source, 0, $result, 0, $length)
    return $result
}

$beforeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $voxPath).Hash
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("cm2-asset-importer-" + [Guid]::NewGuid().ToString("N"))
$assetTempRoot = Join-Path (Join-Path $PSScriptRoot "..\..\Content Mod 2") (".cm2-asset-import-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $assetTempRoot -Force | Out-Null
try {
    $reportOne = Join-Path $tempRoot "report-one.json"
    $reportTwo = Join-Path $tempRoot "report-two.json"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -ReportPath $reportOne *> $null
    Assert-True ($LASTEXITCODE -eq 0) "imports VOX/XML/texture/audio fixture"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runner -ReportPath $reportTwo *> $null
    Assert-True ($LASTEXITCODE -eq 0) "repeats import successfully"
    $first = Get-Content -Raw -LiteralPath $reportOne | ConvertFrom-Json
    $second = Get-Content -Raw -LiteralPath $reportTwo | ConvertFrom-Json
    Assert-True ([string]$first.manifestHash -eq [string]$second.manifestHash) "manifest hash is deterministic across repeated imports"
    Assert-True ([bool]$first.manifest.readOnly) "manifest is read-only"
    $catalogManifestPath = Join-Path $PSScriptRoot "..\..\docs\generated\cm2-generated-catalog-manifest-v1.json"
    $catalogManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $catalogManifestPath).Hash.ToLowerInvariant()
    Assert-True ([string]$first.manifest.catalogBinding.catalogHash -eq $catalogManifestHash -and [string]$first.manifest.catalogBinding.runtimeMode -eq "shadow") "manifest binds generated catalog hash in legacy-safe shadow mode"
    Assert-True ([string]$first.manifest.sourceToVox -eq "logical(x,y,z) -> vox(x, maxZ-1-z, y)") "source-to-VOX coordinate contract is recorded"
    Assert-True ([string]$first.manifest.voxToTeardown -eq "vox(x,y,z) -> logical(x,z,maxZ-1-y)") "VOX-to-Teardown coordinate contract is recorded"
    Assert-True (@($first.manifest.assets).Count -eq 4) "four asset kinds are covered"
    $vox = @($first.manifest.assets | Where-Object { $_.kind -eq "vox" })[0]
    $xml = @($first.manifest.assets | Where-Object { $_.kind -eq "xml" })[0]
    $texture = @($first.manifest.assets | Where-Object { $_.kind -eq "texture" })[0]
    $audio = @($first.manifest.assets | Where-Object { $_.kind -eq "audio" })[0]
    Assert-True ([string]$vox.hash -eq "c52e69f18a71f54f1259d90570a9d6d9bc917e4d26aa4cfbd2242ad69c06788f") "VOX SHA-256 provenance is stable"
    Assert-True ([int]$vox.bytes -eq 17576 -and [int]$vox.complexity.voxelCount -eq 4120) "VOX binary and voxel count are verified"
    Assert-True ((@($vox.logicalSizeVoxels) | ConvertTo-Json -Compress) -eq "[45,12,51]") "VOX logical dimensions use Teardown X/Y/Z"
    Assert-True ([int]$vox.complexity.connectedComponents -eq 1 -and [int]$vox.complexity.paletteColorCount -eq 8) "VOX connected components and palette complexity are reported"
    Assert-True (@($vox.paletteMaterial.PSObject.Properties).Count -eq 8) "palette-material candidates are emitted"
    Assert-True (@($vox.orientationCandidates | Where-Object { $_.confirmed -eq $true }).Count -eq 0) "orientation remains a candidate until visual confirmation"
    Assert-True ([int]$xml.references.Count -eq 2 -and [int]$xml.duplicateReferences.Count -eq 0) "XML prefab resource references and duplicate refs are checked"
    Assert-True ([int]$texture.bytes -gt 0 -and [int]$audio.bytes -gt 0) "texture and audio provenance hashes are emitted"
    Assert-True (@($first.manifest.duplicateHashes).Count -eq 0) "duplicate resource hashes are absent in the fixture"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validateVox -Path $voxPath *> $null
    Assert-True ($LASTEXITCODE -eq 0) "VOX skill validator accepts the binary"
    $afterHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $voxPath).Hash
    Assert-True ($beforeHash -eq $afterHash) "importer does not modify source VOX"

    $baseDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $validBytes = [IO.File]::ReadAllBytes($voxPath)
    $badVox = Join-Path $assetTempRoot "truncated.vox"
    [IO.File]::WriteAllBytes($badVox, (Copy-Bytes $validBytes 100))
    $badFixture = Join-Path $tempRoot "truncated-fixture.json"
    $badDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $badDocument.resources[0].sourceFile = "Content Mod 2/" + (Split-Path -Leaf $assetTempRoot) + "/truncated.vox"
    Write-Fixture $badDocument $badFixture
    Invoke-ExpectedFailure $badFixture "rejects truncated VOX chunks"

    $xyziIndex = Find-Ascii $validBytes "XYZI"
    Assert-True ($xyziIndex -ge 0) "locates XYZI chunk for boundary mutation"
    $outsideBytes = Copy-Bytes $validBytes $validBytes.Length
    $outsideBytes[$xyziIndex + 16] = 255
    $outsideVox = Join-Path $assetTempRoot "outside.vox"
    [IO.File]::WriteAllBytes($outsideVox, $outsideBytes)
    $outsideFixture = Join-Path $tempRoot "outside-fixture.json"
    $outsideDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $outsideDocument.resources[0].sourceFile = "Content Mod 2/" + (Split-Path -Leaf $assetTempRoot) + "/outside.vox"
    Write-Fixture $outsideDocument $outsideFixture
    Invoke-ExpectedFailure $outsideFixture "rejects XYZI coordinate outside SIZE"

    $rgbaIndex = Find-Ascii $validBytes "RGBA"
    Assert-True ($rgbaIndex -gt 0) "locates RGBA chunk for palette mutation"
    $missingPaletteVox = Join-Path $assetTempRoot "missing-palette.vox"
    [IO.File]::WriteAllBytes($missingPaletteVox, (Copy-Bytes $validBytes $rgbaIndex))
    $missingPaletteFixture = Join-Path $tempRoot "missing-palette-fixture.json"
    $missingPaletteDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $missingPaletteDocument.resources[0].sourceFile = "Content Mod 2/" + (Split-Path -Leaf $assetTempRoot) + "/missing-palette.vox"
    Write-Fixture $missingPaletteDocument $missingPaletteFixture
    Invoke-ExpectedFailure $missingPaletteFixture "rejects missing RGBA palette mapping"

    $oversizedFixture = Join-Path $tempRoot "oversized-fixture.json"
    $oversizedDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $oversizedDocument.resources[0].maxVoxels = 100
    Write-Fixture $oversizedDocument $oversizedFixture
    Invoke-ExpectedFailure $oversizedFixture "rejects oversized voxel budget"

    $wrongHashFixture = Join-Path $tempRoot "wrong-hash-fixture.json"
    $wrongHashDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $wrongHashDocument.resources[0].expected.sha256 = ("00" * 32)
    Write-Fixture $wrongHashDocument $wrongHashFixture
    Invoke-ExpectedFailure $wrongHashFixture "rejects wrong expected resource hash"

    $duplicateFixture = Join-Path $tempRoot "duplicate-source-fixture.json"
    $duplicateDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $duplicateDocument.resources[1].sourceFile = $duplicateDocument.resources[0].sourceFile
    Write-Fixture $duplicateDocument $duplicateFixture
    Invoke-ExpectedFailure $duplicateFixture "rejects duplicate resource source path"

    $traversalXml = Join-Path $assetTempRoot "traversal.xml"
    [IO.File]::WriteAllText($traversalXml, '<prefab><vox file="MOD/../outside.vox"/></prefab>', $utf8)
    $traversalFixture = Join-Path $tempRoot "traversal-fixture.json"
    $traversalDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $traversalDocument.resources[1].sourceFile = "Content Mod 2/" + (Split-Path -Leaf $assetTempRoot) + "/traversal.xml"
    Write-Fixture $traversalDocument $traversalFixture
    Invoke-ExpectedFailure $traversalFixture "rejects XML MOD path traversal"

    $missingXml = Join-Path $assetTempRoot "missing.xml"
    [IO.File]::WriteAllText($missingXml, '<prefab><vox file="MOD/vox/does-not-exist.vox"/></prefab>', $utf8)
    $missingFixture = Join-Path $tempRoot "missing-reference-fixture.json"
    $missingDocument = Get-Content -Raw -LiteralPath $fixture | ConvertFrom-Json
    $missingDocument.resources[1].sourceFile = "Content Mod 2/" + (Split-Path -Leaf $assetTempRoot) + "/missing.xml"
    Write-Fixture $missingDocument $missingFixture
    Invoke-ExpectedFailure $missingFixture "rejects missing XML resource reference"
}
finally {
    $contentRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\Content Mod 2")).Path
    $resolvedAssetTemp = (Resolve-Path -LiteralPath $assetTempRoot).Path
    Assert-True ($resolvedAssetTemp.StartsWith($contentRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) "temporary asset fixtures stay inside Content Mod 2"
    if (Test-Path -LiteralPath $assetTempRoot) { Remove-Item -LiteralPath $assetTempRoot -Recurse -Force }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

Write-Host "Self-test passed." -ForegroundColor Green
exit 0
