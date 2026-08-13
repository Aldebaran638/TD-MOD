[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Release,
    [string]$SourceRoot = "",
    [string]$TargetRoot = "",
    [string]$ReleaseRoot = "",
    [string]$SourceRevision = "",
    [string]$GeneratorRevision = "",
    [switch]$SkipPreflight
)

$ErrorActionPreference = "Stop"

$repositoryRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$cmRoot = if ($SourceRoot -eq "") { Join-Path $repositoryRoot "Content Mod 2" } else { [IO.Path]::GetFullPath($SourceRoot) }
$gmRoot = if ($TargetRoot -eq "") { Join-Path $repositoryRoot "Global Mod" } else { [IO.Path]::GetFullPath($TargetRoot) }
$releaseRootFull = if ($ReleaseRoot -eq "") { Join-Path $repositoryRoot ".cm2-release" } else { [IO.Path]::GetFullPath($ReleaseRoot) }

if (-not (Test-Path -LiteralPath $cmRoot -PathType Container)) {
    throw "CM2 directory not found: $cmRoot"
}
if (-not (Test-Path -LiteralPath $gmRoot -PathType Container) -and -not $Release) {
    throw "GM directory not found: $gmRoot"
}

function Get-SafeFullPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$AllowedRoot
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd("\", "/")
    $rootPrefix = $fullRoot + [IO.Path]::DirectorySeparatorChar

    if (-not $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path outside GM: $fullPath"
    }
    return $fullPath
}

function Get-RelativeFilePath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$FullName
    )

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd("\", "/")
    $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    $fullPath = [IO.Path]::GetFullPath($FullName)
    if (-not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "File is not below source root: $fullPath"
    }
    return $fullPath.Substring($prefix.Length)
}

function Test-FilesEqual {
    param(
        [Parameter(Mandatory = $true)][string]$First,
        [Parameter(Mandatory = $true)][string]$Second
    )

    if (-not (Test-Path -LiteralPath $First -PathType Leaf) -or
        -not (Test-Path -LiteralPath $Second -PathType Leaf)) {
        return $false
    }

    $firstFile = Get-Item -LiteralPath $First
    $secondFile = Get-Item -LiteralPath $Second
    if ($firstFile.Length -ne $secondFile.Length) {
        return $false
    }

    return (Get-FileHash -LiteralPath $First -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath $Second -Algorithm SHA256).Hash
}

function Sync-Tree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source tree not found: $Source"
    }

    $destinationPath = Get-SafeFullPath -Path $Destination -AllowedRoot $gmRoot
    $sourceFiles = @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force)
    $sourceMap = @{}
    $added = 0
    $updated = 0
    $removed = 0
    $unchanged = 0

    foreach ($sourceFile in $sourceFiles) {
        $relativePath = Get-RelativeFilePath -Root $Source -FullName $sourceFile.FullName
        $sourceMap[$relativePath.ToLowerInvariant()] = $true
        $targetFile = Get-SafeFullPath `
            -Path (Join-Path $destinationPath $relativePath) `
            -AllowedRoot $gmRoot

        if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
            if (Test-FilesEqual -First $sourceFile.FullName -Second $targetFile) {
                $unchanged++
                continue
            }
            $updated++
        } else {
            $added++
        }

        if (-not $WhatIf) {
            $targetDirectory = Split-Path -Parent $targetFile
            if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetFile -Force
        }
    }

    if (Test-Path -LiteralPath $destinationPath -PathType Container) {
        $destinationFiles = @(Get-ChildItem -LiteralPath $destinationPath -File -Recurse -Force)
        foreach ($destinationFile in $destinationFiles) {
            $relativePath = Get-RelativeFilePath `
                -Root $destinationPath `
                -FullName $destinationFile.FullName
            if (-not $sourceMap.ContainsKey($relativePath.ToLowerInvariant())) {
                $safeFile = Get-SafeFullPath -Path $destinationFile.FullName -AllowedRoot $gmRoot
                $removed++
                if (-not $WhatIf) {
                    Remove-Item -LiteralPath $safeFile -Force
                }
            }
        }

        if (-not $WhatIf) {
            $directories = @(Get-ChildItem -LiteralPath $destinationPath -Directory -Recurse -Force |
                Sort-Object { $_.FullName.Length } -Descending)
            foreach ($directory in $directories) {
                $safeDirectory = Get-SafeFullPath `
                    -Path $directory.FullName `
                    -AllowedRoot $gmRoot
                if (@(Get-ChildItem -LiteralPath $safeDirectory -Force).Count -eq 0) {
                    Remove-Item -LiteralPath $safeDirectory -Force
                }
            }
        }
    }

    return [PSCustomObject]@{
        Tree = $Name
        Added = $added
        Updated = $updated
        Removed = $removed
        Unchanged = $unchanged
    }
}

function Set-GeneratedTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $targetFile = Get-SafeFullPath -Path $Destination -AllowedRoot $gmRoot
    $existing = $null
    if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
        $existing = [IO.File]::ReadAllText($targetFile)
    }
    if ($existing -ceq $Content) {
        return "Unchanged"
    }

    if (-not $WhatIf) {
        $utf8WithoutBom = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($targetFile, $Content, $utf8WithoutBom)
    }
    if ($null -eq $existing) {
        return "Added"
    }
    return "Updated"
}

function Assert-TreesEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $sourceFiles = @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force)
    $destinationFiles = @(Get-ChildItem -LiteralPath $Destination -File -Recurse -Force)
    if ($sourceFiles.Count -ne $destinationFiles.Count) {
        throw "Verification failed: file count differs for $Destination"
    }

    foreach ($sourceFile in $sourceFiles) {
        $relativePath = Get-RelativeFilePath -Root $Source -FullName $sourceFile.FullName
        $targetFile = Join-Path $Destination $relativePath
        if (-not (Test-FilesEqual -First $sourceFile.FullName -Second $targetFile)) {
            throw "Verification failed: $relativePath"
        }
    }
}

# Release Builder v1 -------------------------------------------------------
# The legacy incremental sync remains available when -Release is omitted.
# Release mode is deliberately staged and atomic: all generated trees are
# assembled beside the target, a deterministic manifest is written, and only
# then is the previous Global Mod moved to the explicit rollback directory.
function Get-ReleaseCanonicalJson {
    param([Parameter(Mandatory = $true)][object]$Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Get-ReleaseSha256Text {
    param([Parameter(Mandatory = $true)][string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return (([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace("-", "").ToLowerInvariant())
    } finally { $sha.Dispose() }
}

function Write-ReleaseJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $utf8WithoutBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, (Get-ReleaseCanonicalJson $Value) + "`n", $utf8WithoutBom)
}

function Get-ReleaseFileRecords {
    param([Parameter(Mandatory = $true)][string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return @() }
    $fullRoot = (Resolve-Path -LiteralPath $Root).Path.TrimEnd("\", "/")
    $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($file in @(Get-ChildItem -LiteralPath $fullRoot -Recurse -File -Force | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($prefix.Length).Replace("\", "/")
        [void]$records.Add([ordered]@{
            path = $relative
            bytes = [int64]$file.Length
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        })
    }
    return @($records.ToArray())
}

function Get-ReleaseTreeHash {
    param([Parameter(Mandatory = $true)][string]$Root)
    $records = @(Get-ReleaseFileRecords -Root $Root)
    return Get-ReleaseSha256Text (Get-ReleaseCanonicalJson $records)
}

function Copy-ReleaseTree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Release source tree not found: $Source" }
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }
    $sourceFull = (Resolve-Path -LiteralPath $Source).Path.TrimEnd("\", "/")
    $prefix = $sourceFull + [IO.Path]::DirectorySeparatorChar
    foreach ($file in @(Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Force)) {
        $relative = $file.FullName.Substring($prefix.Length)
        $target = Join-Path $Destination $relative
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }
}

function Invoke-ReleaseCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) { throw "Release preflight tool missing: $ScriptPath" }
    $saved = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    if ($code -ne 0) { throw "Release preflight failed: $Label (exit $code)" }
    return [ordered]@{ label = $Label; status = "pass" }
}

function Invoke-ReleasePreflight {
    $harnessRoot = Join-Path $repositoryRoot "harness"
    $checks = New-Object System.Collections.Generic.List[object]
    $checkList = @(
        @{ Label = "entry-closures"; Script = "check-entry-closures.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "lua"; Script = "check-lua.ps1"; Arguments = @("-Path", (Join-Path $cmRoot "script")) },
        @{ Label = "teardown-api"; Script = "check-teardown-api.ps1"; Arguments = @("-Path", (Join-Path $cmRoot "script")) },
        @{ Label = "xml"; Script = "check-xml.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "schema"; Script = "check-schema-v1.ps1"; Arguments = @("-Path", $repositoryRoot) },
        @{ Label = "generated-catalog-manifest"; Script = "check-generated-catalog-manifest-v1.ps1"; Arguments = @("-Path", $repositoryRoot) },
        @{ Label = "charged-weapons"; Script = "check-charged-weapons.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "noncharged-lasers"; Script = "check-noncharged-lasers.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "ballistic-weapons"; Script = "check-ballistic-weapons.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "weapon-rendering"; Script = "check-weapon-rendering.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "weapon-directory"; Script = "check-weapon-directory-structure.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "explicit-weapons"; Script = "data\weapons\check-explicit-weapon-definitions.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "explicit-components"; Script = "data\components\check-explicit-component-definitions.ps1"; Arguments = @("-Path", $cmRoot) },
        @{ Label = "ship-definitions"; Script = "data\ships\check-ship-definitions.ps1"; Arguments = @("-Path", $cmRoot) }
    )
    foreach ($check in $checkList) {
        [void]$checks.Add((Invoke-ReleaseCheck -Label $check.Label -ScriptPath (Join-Path $harnessRoot $check.Script) -Arguments $check.Arguments))
    }
    return @($checks.ToArray())
}

function Invoke-ReleasePublish {
    param(
        [Parameter(Mandatory = $true)][string]$Staging,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$ReleaseDirectory,
        [Parameter(Mandatory = $true)][string]$ReleaseId
    )
    if (-not (Test-Path -LiteralPath $ReleaseDirectory -PathType Container)) { New-Item -ItemType Directory -Path $ReleaseDirectory -Force | Out-Null }
    $previous = Join-Path $ReleaseDirectory "previous"
    if (Test-Path -LiteralPath $previous) { Remove-Item -LiteralPath $previous -Recurse -Force -ErrorAction SilentlyContinue }
    $targetParent = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) { New-Item -ItemType Directory -Path $targetParent -Force | Out-Null }
    if (Test-Path -LiteralPath $Target) { Move-Item -LiteralPath $Target -Destination $previous -Force }
    try {
        Move-Item -LiteralPath $Staging -Destination $Target -Force
    } catch {
        if ((Test-Path -LiteralPath $previous) -and -not (Test-Path -LiteralPath $Target)) { Move-Item -LiteralPath $previous -Destination $Target -Force }
        throw
    }
    $rollback = [ordered]@{
        schema = "cm2.release-rollback/1"
        releaseId = $ReleaseId
        target = "Global Mod"
        previous = "previous"
        restore = "Move the release-root/previous directory back to the target Global Mod directory."
        status = "available"
    }
    Write-ReleaseJson -Path (Join-Path $ReleaseDirectory "rollback.json") -Value $rollback
    return "published"
}

function Invoke-ReleaseBuilder {
    if ([IO.Path]::GetFullPath($releaseRootFull).StartsWith(([IO.Path]::GetFullPath($cmRoot).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) { throw "Release root cannot be inside Content Mod 2." }
    if ([IO.Path]::GetFullPath($releaseRootFull).StartsWith(([IO.Path]::GetFullPath($gmRoot).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) { throw "Release root cannot be inside Global Mod." }
    if (-not (Test-Path -LiteralPath $cmRoot -PathType Container)) { throw "Release source tree not found: $cmRoot" }
    if (-not $SkipPreflight) { $preflight = @(Invoke-ReleasePreflight) } else { $preflight = @([ordered]@{ label = "preflight"; status = "skipped-by-explicit-flag" }) }

    $sourceHash = Get-ReleaseTreeHash -Root $cmRoot
    if ($SourceRevision -eq "") { $SourceRevision = "tree:$sourceHash" }
    if ($GeneratorRevision -eq "") {
        $generatorHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
        $GeneratorRevision = "script:$generatorHash"
    }
    $releaseId = "cm2-release-" + $sourceHash.Substring(0, 16)
    $stagingParent = Join-Path $releaseRootFull ".staging"
    if (-not (Test-Path -LiteralPath $stagingParent -PathType Container)) { New-Item -ItemType Directory -Path $stagingParent -Force | Out-Null }
    $staging = Join-Path $stagingParent $releaseId
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    try {
        # Preserve explicitly unmanaged legacy files, but replace every mapped
        # generated tree from a clean source copy.
        if (Test-Path -LiteralPath $gmRoot -PathType Container) { Copy-ReleaseTree -Source $gmRoot -Destination $staging }
        $treeMappings = @(
            @{ Name = "script"; Source = "script"; Destination = "script" },
            @{ Name = "gfx"; Source = "gfx"; Destination = "gfx" },
            @{ Name = "prefabs"; Source = "prefabs"; Destination = "prefabs" },
            @{ Name = "sound"; Source = "sound"; Destination = "sound" },
            @{ Name = "vox"; Source = "vox"; Destination = "vox" }
        )
        $mappedResults = New-Object System.Collections.Generic.List[object]
        foreach ($mapping in $treeMappings) {
            $sourceTree = Join-Path $cmRoot $mapping.Source
            $destinationTree = Join-Path $staging $mapping.Destination
            if (Test-Path -LiteralPath $destinationTree) { Remove-Item -LiteralPath $destinationTree -Recurse -Force }
            Copy-ReleaseTree -Source $sourceTree -Destination $destinationTree
            [void]$mappedResults.Add([ordered]@{ name = $mapping.Name; source = $mapping.Source; destination = $mapping.Destination; sourceHash = Get-ReleaseTreeHash -Root $sourceTree; outputHash = Get-ReleaseTreeHash -Root $destinationTree })
        }
        $mainSource = Join-Path $cmRoot "main.lua"
        if (-not (Test-Path -LiteralPath $mainSource -PathType Leaf)) { throw "Release source main.lua is missing." }
        Copy-Item -LiteralPath $mainSource -Destination (Join-Path $staging "main.lua") -Force
        $prefabSource = Join-Path $cmRoot "prefabs\ships\enigma_battlecruiser.xml"
        if (-not (Test-Path -LiteralPath $prefabSource -PathType Leaf)) { throw "Release source battlecruiser prefab is missing." }
        $prefabText = [IO.File]::ReadAllText($prefabSource)
        $scriptStart = $prefabText.IndexOf("<script ", [StringComparison]::Ordinal)
        $scriptEndMarker = "</script>"
        if ($scriptStart -lt 0) { throw "Release source battlecruiser prefab has no root script block." }
        $scriptEnd = $prefabText.IndexOf($scriptEndMarker, $scriptStart, [StringComparison]::Ordinal)
        if ($scriptEnd -lt 0) { throw "Release source battlecruiser prefab script block is not closed." }
        $scriptEnd += $scriptEndMarker.Length
        $spawnFragment = $prefabText.Substring($scriptStart, $scriptEnd - $scriptStart).Trim() + "`r`n"
        Write-ReleaseJson -Path (Join-Path $staging "release-fragment.json") -Value ([ordered]@{ source = "prefabs/ships/enigma_battlecruiser.xml"; generatedTarget = "enigma_battlecruiser.xml"; sha256 = Get-ReleaseSha256Text $spawnFragment })
        $utf8WithoutBom = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText((Join-Path $staging "enigma_battlecruiser.xml"), $spawnFragment, $utf8WithoutBom)

        $preManifestRecords = @(Get-ReleaseFileRecords -Root $staging | Where-Object { $_.path -ne "release-manifest.json" })
        $payloadHash = Get-ReleaseSha256Text (Get-ReleaseCanonicalJson $preManifestRecords)
        $sourceOfTruthPath = Join-Path $repositoryRoot "docs\source-of-truth.json"
        $sourceOfTruthHash = if (Test-Path -LiteralPath $sourceOfTruthPath -PathType Leaf) { (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceOfTruthPath).Hash.ToLowerInvariant() } else { "missing" }
        $manifest = [ordered]@{
            schema = "cm2.release-manifest/1"
            release_id = $releaseId
            source_root = "Content Mod 2"
            generated_target = "Global Mod"
            source_revision = $SourceRevision
            generator_revision = $GeneratorRevision
            package_hash = $sourceHash
            generated_at = "deterministic:$sourceHash"
            source_of_truth_hash = $sourceOfTruthHash
            preflight = @($preflight)
            managed_mappings = @($mappedResults.ToArray())
            preserved_unmanaged_files = @($preManifestRecords | Where-Object { $_.path -notmatch '^(script|gfx|prefabs|sound|vox)/' -and $_.path -notin @("main.lua", "enigma_battlecruiser.xml") })
            output_hash = $payloadHash
            manual_edit = "forbidden"
            rollback = "release-root/previous"
            runtime_policy = "Global Mod is generated output; live Teardown smoke remains a release gate."
        }
        Write-ReleaseJson -Path (Join-Path $staging "release-manifest.json") -Value $manifest
        $releaseReport = [ordered]@{ schema = "cm2.release-report/1"; releaseId = $releaseId; sourceRevision = $SourceRevision; generatorRevision = $GeneratorRevision; packageHash = $sourceHash; outputHash = $payloadHash; target = $gmRoot; mode = if ($WhatIf) { "preview" } else { "published" }; preflight = @($preflight); status = "pass" }
        if (-not $WhatIf) {
            $status = Invoke-ReleasePublish -Staging $staging -Target $gmRoot -ReleaseDirectory $releaseRootFull -ReleaseId $releaseId
            $releaseReport.status = $status
            $publishedManifest = Join-Path $gmRoot "release-manifest.json"
            if (-not (Test-Path -LiteralPath $publishedManifest -PathType Leaf)) { throw "Release verification failed: release-manifest.json is missing." }
            $publishedPayloadHash = Get-ReleaseSha256Text (Get-ReleaseCanonicalJson (@(Get-ReleaseFileRecords -Root $gmRoot | Where-Object { $_.path -ne "release-manifest.json" })))
            if ($publishedPayloadHash -ne $payloadHash) { throw "Release verification failed: output hash differs after publication." }
        }
        Write-Output (Get-ReleaseCanonicalJson $releaseReport)
        return $releaseReport
    }
    finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

if ($Release) {
    Invoke-ReleaseBuilder | Out-Null
    exit 0
}

$treeMappings = @(
    @{ Name = "script"; Source = "script"; Destination = "script" },
    @{ Name = "gfx"; Source = "gfx"; Destination = "gfx" },
    @{ Name = "prefabs"; Source = "prefabs"; Destination = "prefabs" },
    @{ Name = "sound"; Source = "sound"; Destination = "sound" },
    @{ Name = "vox"; Source = "vox"; Destination = "vox" }
)

$results = @()
foreach ($mapping in $treeMappings) {
    $sourceTree = Join-Path $cmRoot $mapping.Source
    $destinationTree = Join-Path $gmRoot $mapping.Destination
    $results += Sync-Tree `
        -Source $sourceTree `
        -Destination $destinationTree `
        -Name $mapping.Name
}

$configuratorSource = Join-Path $cmRoot "main.lua"
$gmMain = Join-Path $gmRoot "main.lua"
$configuratorText = [IO.File]::ReadAllText($configuratorSource)
$gmMainText = $configuratorText
$mainStatus = Set-GeneratedTextFile -Destination $gmMain -Content $gmMainText

$battlecruiserPrefab = Join-Path $cmRoot "prefabs\ships\enigma_battlecruiser.xml"
$prefabText = [IO.File]::ReadAllText($battlecruiserPrefab)
$scriptStart = $prefabText.IndexOf("<script ", [StringComparison]::Ordinal)
$scriptEndMarker = "</script>"
if ($scriptStart -lt 0) {
    throw "Battlecruiser prefab has no root script block."
}
$scriptEnd = $prefabText.IndexOf($scriptEndMarker, $scriptStart, [StringComparison]::Ordinal)
if ($scriptEnd -lt 0) {
    throw "Battlecruiser prefab script block is not closed."
}
$scriptEnd += $scriptEndMarker.Length
$spawnFragment = $prefabText.Substring($scriptStart, $scriptEnd - $scriptStart).Trim() + "`r`n"
$spawnStatus = Set-GeneratedTextFile `
    -Destination (Join-Path $gmRoot "enigma_battlecruiser.xml") `
    -Content $spawnFragment

$mode = if ($WhatIf) { "PREVIEW" } else { "SYNCED" }
Write-Host "CM2 -> GM $mode"
$results | Format-Table -AutoSize
Write-Host ("main.lua: {0}; enigma_battlecruiser.xml: {1}" -f $mainStatus, $spawnStatus)

if (-not $WhatIf) {
    foreach ($mapping in $treeMappings) {
        Assert-TreesEqual `
            -Source (Join-Path $cmRoot $mapping.Source) `
            -Destination (Join-Path $gmRoot $mapping.Destination)
    }
    $writtenMain = [IO.File]::ReadAllText($gmMain)
    if ($writtenMain -cne $gmMainText) {
        throw "Verification failed: Global Mod/main.lua"
    }
    $writtenSpawn = [IO.File]::ReadAllText((Join-Path $gmRoot "enigma_battlecruiser.xml"))
    if ($writtenSpawn -cne $spawnFragment) {
        throw "Verification failed: Global Mod/enigma_battlecruiser.xml"
    }
    Write-Host "Hash/content verification passed."
}
