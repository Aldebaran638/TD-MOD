# Read-only Asset Importer / AssetManifest v1.
# It inspects VOX/XML and emits a deterministic report; it never modifies source
# assets, generated Lua, prefabs, textures or audio.

param(
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\asset-importer-v1.fixture.json" }

function Fail([string]$message) { throw ("Asset Importer v1 failed: " + $message) }
function Require([bool]$condition, [string]$message) { if (-not $condition) { Fail $message } }
function Sha256-Bytes([byte[]]$bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant() } finally { $sha.Dispose() }
}
function Sha256-File([string]$path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }
function Read-U32([byte[]]$bytes, [ref]$cursor, [string]$context) {
    if ($cursor.Value -lt 0 -or $cursor.Value + 4 -gt $bytes.Length) { Fail ("truncated uint32 in " + $context) }
    $value = [BitConverter]::ToUInt32($bytes, $cursor.Value)
    $cursor.Value += 4
    return [uint32]$value
}
function Read-I32([byte[]]$bytes, [ref]$cursor, [string]$context) {
    if ($cursor.Value -lt 0 -or $cursor.Value + 4 -gt $bytes.Length) { Fail ("truncated int32 in " + $context) }
    $value = [BitConverter]::ToInt32($bytes, $cursor.Value)
    $cursor.Value += 4
    return [int]$value
}
function Parse-Chunks([byte[]]$bytes, [int]$start, [int]$end) {
    $cursor = $start
    $chunks = New-Object System.Collections.Generic.List[object]
    while ($cursor -lt $end) {
        if ($cursor + 12 -gt $end) { Fail "truncated VOX chunk header" }
        $id = [Text.Encoding]::ASCII.GetString($bytes, $cursor, 4)
        $cursor += 4
        $contentSize = [int](Read-U32 $bytes ([ref]$cursor) ("chunk " + $id + " content size"))
        $childSize = [int](Read-U32 $bytes ([ref]$cursor) ("chunk " + $id + " child size"))
        $contentStart = $cursor
        $contentEnd = $contentStart + $contentSize
        $childStart = $contentEnd
        $childEnd = $childStart + $childSize
        if ($contentEnd -gt $end -or $childEnd -gt $end -or $contentEnd -lt $contentStart -or $childEnd -lt $childStart) { Fail ("VOX chunk range escapes file: " + $id + " contentEnd=" + $contentEnd + " childEnd=" + $childEnd + " end=" + $end + " contentStart=" + $contentStart + " childStart=" + $childStart) }
        $children = @()
        if ($childSize -gt 0) { $children = @(Parse-Chunks $bytes $childStart $childEnd) }
        $chunks.Add([pscustomobject]@{ id = $id; contentSize = $contentSize; childSize = $childSize; contentStart = $contentStart; children = $children })
        $cursor = $childEnd
    }
    if ($cursor -ne $end) { Fail "VOX chunk stream has a non-zero tail" }
    return $chunks.ToArray()
}
function Flatten-Chunks([object[]]$chunks) {
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($chunk in @($chunks)) {
        $result.Add($chunk)
        foreach ($child in @(Flatten-Chunks @($chunk.children))) { $result.Add($child) }
    }
    return $result.ToArray()
}
function Chunk-Bytes([byte[]]$bytes, [object]$chunk) {
    $content = New-Object byte[] ([int]$chunk.contentSize)
    if ($content.Length -gt 0) { [Array]::Copy($bytes, [int]$chunk.contentStart, $content, 0, $content.Length) }
    return $content
}
function Connected-Components([hashtable]$voxelSet) {
    $remaining = @{}
    foreach ($key in $voxelSet.Keys) { $remaining[$key] = $true }
    $components = 0
    $largest = 0
    while ($remaining.Count -gt 0) {
        $seed = @($remaining.Keys)[0]
        $remaining.Remove($seed)
        $stack = New-Object System.Collections.Generic.List[string]
        $stack.Add([string]$seed)
        $size = 0
        while ($stack.Count -gt 0) {
            $last = $stack[$stack.Count - 1]
            $stack.RemoveAt($stack.Count - 1)
            $size++
            $parts = $last.Split(",")
            $x = [int]$parts[0]; $y = [int]$parts[1]; $z = [int]$parts[2]
            foreach ($delta in @(@(1,0,0), @(-1,0,0), @(0,1,0), @(0,-1,0), @(0,0,1), @(0,0,-1))) {
                $neighbor = "{0},{1},{2}" -f ($x + $delta[0]), ($y + $delta[1]), ($z + $delta[2])
                if ($remaining.ContainsKey($neighbor)) { $remaining.Remove($neighbor); $stack.Add($neighbor) }
            }
        }
        $components++
        if ($size -gt $largest) { $largest = $size }
    }
    return [pscustomobject]@{ count = $components; largest = $largest }
}
function Import-Vox([string]$path, [object]$spec) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) ("VOX source missing: " + $path)
    $bytes = [IO.File]::ReadAllBytes($path)
    Require ($bytes.Length -ge 20) ("VOX source is truncated: " + $path)
    $magic = [Text.Encoding]::ASCII.GetString($bytes, 0, 4)
    Require ($magic -eq "VOX ") ("VOX magic mismatch: " + $path)
    $cursor = 4
    $version = Read-U32 $bytes ([ref]$cursor) "VOX version"
    Require ($version -eq 150) ("unsupported VOX version: " + [string]$version)
    $roots = @(Parse-Chunks $bytes 8 $bytes.Length)
    Require ($roots.Count -eq 1 -and $roots[0].id -eq "MAIN") "VOX root MAIN chunk is missing"
    $all = @(Flatten-Chunks $roots)
    $sizeChunk = @($all | Where-Object { $_.id -eq "SIZE" })[0]
    $xyziChunk = @($all | Where-Object { $_.id -eq "XYZI" })[0]
    $rgbaChunks = @($all | Where-Object { $_.id -eq "RGBA" })
    Require ($null -ne $sizeChunk -and $null -ne $xyziChunk) "VOX SIZE/XYZI chunk is missing"
    $sizeBytes = Chunk-Bytes $bytes $sizeChunk
    Require ($sizeBytes.Length -eq 12) "VOX SIZE content must be 12 bytes"
    $sizeCursor = 0
    $voxSizeX = Read-I32 $sizeBytes ([ref]$sizeCursor) "VOX SIZE X"
    $voxSizeY = Read-I32 $sizeBytes ([ref]$sizeCursor) "VOX SIZE Y"
    $voxSizeZ = Read-I32 $sizeBytes ([ref]$sizeCursor) "VOX SIZE Z"
    Require ($voxSizeX -gt 0 -and $voxSizeY -gt 0 -and $voxSizeZ -gt 0) "VOX dimensions must be positive"
    $xyziBytes = Chunk-Bytes $bytes $xyziChunk
    Require ($xyziBytes.Length -ge 4) "VOX XYZI is truncated"
    $xyziCursor = 0
    $voxelCount = [int](Read-U32 $xyziBytes ([ref]$xyziCursor) "VOX XYZI count")
    Require ($xyziBytes.Length -eq (4 + ($voxelCount * 4))) "VOX XYZI content size does not match voxel count"
    $maxVoxels = if ($null -ne $spec.maxVoxels) { [int]$spec.maxVoxels } else { 2000000 }
    Require ($maxVoxels -gt 0 -and $voxelCount -le $maxVoxels) ("VOX voxel count exceeds importer budget: " + $voxelCount)
    $voxels = @{}
    $palette = @{}
    $minX = [int]::MaxValue; $minY = [int]::MaxValue; $minZ = [int]::MaxValue
    $maxX = [int]::MinValue; $maxY = [int]::MinValue; $maxZ = [int]::MinValue
    for ($index = 0; $index -lt $voxelCount; $index++) {
        $x = [int]$xyziBytes[$xyziCursor]; $y = [int]$xyziBytes[$xyziCursor + 1]; $z = [int]$xyziBytes[$xyziCursor + 2]; $color = [int]$xyziBytes[$xyziCursor + 3]; $xyziCursor += 4
        Require ($x -lt $voxSizeX -and $y -lt $voxSizeY -and $z -lt $voxSizeZ) "VOX voxel coordinate is outside SIZE bounds"
        $key = "{0},{1},{2}" -f $x, $y, $z
        Require (-not $voxels.ContainsKey($key)) "VOX contains duplicate voxel coordinates"
        $voxels[$key] = $color
        $palette[$color] = $true
        $minX = [Math]::Min($minX, $x); $minY = [Math]::Min($minY, $y); $minZ = [Math]::Min($minZ, $z)
        $maxX = [Math]::Max($maxX, $x); $maxY = [Math]::Max($maxY, $y); $maxZ = [Math]::Max($maxZ, $z)
    }
    Require ($rgbaChunks.Count -eq 1) "VOX RGBA palette chunk is missing or duplicated"
    Require ((Chunk-Bytes $bytes $rgbaChunks[0]).Length -eq 1024) "VOX RGBA content must be 1024 bytes"
    $components = Connected-Components $voxels
    $metersPerVoxel = if ($null -ne $spec.metersPerVoxel) { [double]$spec.metersPerVoxel } else { 0.1 }
    Require ($metersPerVoxel -gt 0) "metersPerVoxel must be positive"
    $logical = [ordered]@{ x = $voxSizeX; y = $voxSizeZ; z = $voxSizeY }
    if ($minX -is [array] -or $minY -is [array] -or $minZ -is [array] -or $maxX -is [array] -or $maxY -is [array] -or $maxZ -is [array] -or $metersPerVoxel -is [array]) { Fail ("VOX scalar normalization failed: minX=" + ($minX -join ",") + " maxX=" + ($maxX -join ",") + " meters=" + ($metersPerVoxel -join ",")) }
    $bounds = [ordered]@{
        vox = [ordered]@{ min = @($minX,$minY,$minZ); max = @($maxX,$maxY,$maxZ) }
        meters = [ordered]@{ min = @(($minX*$metersPerVoxel),($minY*$metersPerVoxel),($minZ*$metersPerVoxel)); max = @(($maxX*$metersPerVoxel),($maxY*$metersPerVoxel),($maxZ*$metersPerVoxel)) }
    }
    $nonEmpty = $voxSizeX * $voxSizeY * $voxSizeZ
    $fill = if ($nonEmpty -gt 0) { [Math]::Round($voxelCount / [double]$nonEmpty, 6) } else { 0 }
    $paletteMaterials = [ordered]@{}
    foreach ($color in ($palette.Keys | Sort-Object {[int]$_})) { $paletteMaterials[[string]$color] = "candidate-unknown" }
    $hash = Sha256-Bytes $bytes
    if ($null -ne $spec.expected -and -not [string]::IsNullOrWhiteSpace([string]$spec.expected.sha256)) { Require ($hash -eq ([string]$spec.expected.sha256).ToLowerInvariant()) ("VOX hash mismatch: " + $path) }
    return [ordered]@{
        kind = "vox"
        sourceFile = [string]$spec.sourceFile
        hash = $hash
        bytes = $bytes.Length
        license = [string]$spec.license
        provenance = [string]$spec.provenance
        importerVersion = "cm2.asset-importer/1.0.0"
        sourceUnits = "voxels"
        sourceToVox = "logical(x,y,z) -> vox(x, maxZ-1-z, y)"
        voxToTeardown = "vox(x,y,z) -> logical(x,z,maxZ-1-y)"
        metersPerVoxel = $metersPerVoxel
        logicalSizeVoxels = @($logical.x,$logical.y,$logical.z)
        voxSize = @($voxSizeX,$voxSizeY,$voxSizeZ)
        paletteMaterial = $paletteMaterials
        bounds = $bounds
        complexity = [ordered]@{ voxelCount = $voxelCount; paletteColorCount = $palette.Count; connectedComponents = $components.count; largestComponentVoxelCount = $components.largest; fillFraction = $fill; chunkIds = @($all | ForEach-Object { [string]$_.id }) }
        orientationCandidates = @(
            [ordered]@{ name = "teardown-y-up-forward-minus-z"; up = "+Y"; forward = "-Z"; confidence = 0.98; confirmed = $false },
            [ordered]@{ name = "legacy-vox-axis-review"; up = "+VOX-Z"; forward = "+VOX-Y"; confidence = 0.42; confirmed = $false }
        )
        readOnly = $true
    }
}
function Resolve-ModPath([string]$modRoot, [string]$reference) {
    Require (-not [IO.Path]::IsPathRooted($reference)) ("absolute asset reference is forbidden: " + $reference)
    Require ($reference.StartsWith("MOD/", [StringComparison]::OrdinalIgnoreCase)) ("asset reference must use MOD/: " + $reference)
    $relative = $reference.Substring(4).Replace("/", [IO.Path]::DirectorySeparatorChar)
    $resolved = [IO.Path]::GetFullPath((Join-Path $modRoot $relative))
    $prefix = $modRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Require ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) ("asset reference escapes MOD root: " + $reference)
    return $resolved
}
function Import-Generic([string]$path, [string]$kind, [object]$spec) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) ("referenced resource missing: " + $path)
    $bytes = [IO.File]::ReadAllBytes($path)
    $hash = Sha256-Bytes $bytes
    if ($null -ne $spec.expected -and -not [string]::IsNullOrWhiteSpace([string]$spec.expected.sha256)) { Require ($hash -eq ([string]$spec.expected.sha256).ToLowerInvariant()) ("resource hash mismatch: " + $path) }
    return [ordered]@{ kind = $kind; sourceFile = [string]$spec.sourceFile; hash = $hash; bytes = $bytes.Length; license = [string]$spec.license; provenance = [string]$spec.provenance; importerVersion = "cm2.asset-importer/1.0.0"; sourceUnits = "binary-resource"; readOnly = $true }
}
function Import-Xml([string]$path, [object]$spec, [string]$modRoot) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) ("XML source missing: " + $path)
    try { [xml]$xml = Get-Content -Raw -LiteralPath $path } catch { Fail ("XML parse failed: " + $path) }
    $references = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    foreach ($node in @($xml.SelectNodes("//*[@file]"))) {
        $reference = [string]$node.file
        $resolved = Resolve-ModPath $modRoot $reference
        $relative = $resolved.Substring($modRoot.Length + 1).Replace("\", "/")
        if ($seen.ContainsKey($relative)) { $seen[$relative] = [int]$seen[$relative] + 1 } else { $seen[$relative] = 1 }
        $references.Add([ordered]@{ reference = $reference; resolvedSourceFile = ("Content Mod 2/" + $relative); node = [string]$node.name; kind = ([IO.Path]::GetExtension($resolved).TrimStart(".").ToLowerInvariant()); exists = (Test-Path -LiteralPath $resolved -PathType Leaf) })
        Require (Test-Path -LiteralPath $resolved -PathType Leaf) ("XML resource reference is missing: " + $reference)
    }
    $duplicateReferences = @($seen.GetEnumerator() | Where-Object { [int]$_.Value -gt 1 } | ForEach-Object { [string]$_.Key })
    $transforms = New-Object System.Collections.Generic.List[object]
    foreach ($node in @($xml.SelectNodes("//*[@pos or @rot]"))) { $transforms.Add([ordered]@{ name = [string]$node.name; pos = [string]$node.pos; rot = [string]$node.rot; candidate = $true; confidence = 0.55 }) }
    $hash = Sha256-File $path
    if ($null -ne $spec.expected -and -not [string]::IsNullOrWhiteSpace([string]$spec.expected.sha256)) { Require ($hash -eq ([string]$spec.expected.sha256).ToLowerInvariant()) ("XML hash mismatch: " + $path) }
    return [ordered]@{ kind = "xml"; sourceFile = [string]$spec.sourceFile; hash = $hash; bytes = (Get-Item -LiteralPath $path).Length; license = [string]$spec.license; provenance = [string]$spec.provenance; importerVersion = "cm2.asset-importer/1.0.0"; sourceUnits = "Teardown XML units"; references = $references.ToArray(); duplicateReferences = $duplicateReferences; nodeTransforms = $transforms.ToArray(); readOnly = $true }
}
function Import-Resource([object]$spec, [string]$modRoot) {
    $relative = [string]$spec.sourceFile
    Require ($relative.StartsWith("Content Mod 2/", [StringComparison]::OrdinalIgnoreCase)) ("fixture source must stay in Content Mod 2: " + $relative)
    $relativeInside = $relative.Substring("Content Mod 2/".Length).Replace("/", [IO.Path]::DirectorySeparatorChar)
    $path = [IO.Path]::GetFullPath((Join-Path $modRoot $relativeInside))
    $prefix = $modRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Require ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) ("source path escapes Content Mod 2: " + $relative)
    $kind = [string]$spec.kind
    if ($kind -eq "vox") { return Import-Vox $path $spec }
    if ($kind -eq "xml") { return Import-Xml $path $spec $modRoot }
    return Import-Generic $path $kind $spec
}

$fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
Require ([string]$fixture.schema -eq "cm2.asset-importer/1") "fixture schema mismatch"
Require ([string]$fixture.importerVersion -eq "cm2.asset-importer/1.0.0") "importer version mismatch"
$modRoot = (Resolve-Path (Join-Path $root "Content Mod 2")).Path
$assets = New-Object System.Collections.Generic.List[object]
$hashes = @{}
$paths = @{}
foreach ($spec in @($fixture.resources)) {
    $source = [string]$spec.sourceFile
    Require (-not $paths.ContainsKey($source)) ("duplicate source path in manifest: " + $source)
    $paths[$source] = $true
    $report = Import-Resource $spec $modRoot
    $assets.Add([pscustomobject]$report)
    if ($hashes.ContainsKey([string]$report.hash)) { $hashes[[string]$report.hash] = @($hashes[[string]$report.hash]) + $source } else { $hashes[[string]$report.hash] = @($source) }
}
$duplicateHashes = @($hashes.GetEnumerator() | Where-Object { @($_.Value).Count -gt 1 } | ForEach-Object { [ordered]@{ hash = [string]$_.Key; sourceFiles = @($_.Value) } })
$catalogRelativePath = "docs/generated/cm2-generated-catalog-manifest-v1.json"
$catalogPath = Join-Path $root $catalogRelativePath
Require (Test-Path -LiteralPath $catalogPath -PathType Leaf) "generated catalog manifest is missing"
$catalogBinding = [ordered]@{ path = $catalogRelativePath; catalogHash = Sha256-File $catalogPath; ownership = "generated-candidate-only"; runtimeMode = "shadow" }
$manifestCore = [ordered]@{
    schema = "cm2.asset-manifest/1"
    importerVersion = [string]$fixture.importerVersion
    readOnly = $true
    sourceRoot = "Content Mod 2"
    sourceToVox = "logical(x,y,z) -> vox(x, maxZ-1-z, y)"
    voxToTeardown = "vox(x,y,z) -> logical(x,z,maxZ-1-y)"
    catalogBinding = $catalogBinding
    assets = $assets.ToArray()
    duplicateHashes = $duplicateHashes
}
$manifestJson = $manifestCore | ConvertTo-Json -Depth 50 -Compress
$manifestHash = Sha256-Bytes ([Text.Encoding]::UTF8.GetBytes($manifestJson))
$report = [ordered]@{ schema = "cm2.asset-importer-report/1"; importerVersion = [string]$fixture.importerVersion; manifestHash = $manifestHash; manifest = $manifestCore; result = "pass" }
$json = $report | ConvertTo-Json -Depth 60
if ($ReportPath -ne "") {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $reportAbsolute = if ([IO.Path]::IsPathRooted($ReportPath)) { [IO.Path]::GetFullPath($ReportPath) } else { [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $ReportPath)) }
    [IO.File]::WriteAllText($reportAbsolute, $json, (New-Object Text.UTF8Encoding($false)))
}
Write-Output $json
Write-Host "Asset Importer v1 passed: read-only VOX/XML provenance, bounds/complexity, coordinate candidates and deterministic manifest." -ForegroundColor Green
exit 0
