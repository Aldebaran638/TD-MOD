# Validates every real XML/Lua entry point and its local include closure.

param(
    [string]$Path = ".\Content Mod 2"
)

$ErrorActionPreference = "Stop"
Write-Host "=== Teardown Entry Closure Checker ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Mod root does not exist: $Path" -ForegroundColor Red
    exit 1
}

$modRoot = (Resolve-Path -LiteralPath $Path).Path.TrimEnd("\", "/")
$rootPrefix = $modRoot + [IO.Path]::DirectorySeparatorChar
$errors = New-Object System.Collections.Generic.List[string]
$entries = New-Object System.Collections.Generic.List[string]
$graph = @{}
$state = @{}

function Get-RelativePath([string]$fullPath) {
    if ($fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($rootPrefix.Length).Replace("\", "/")
    }
    return $fullPath.Replace("\", "/")
}

function Add-Error([string]$message) {
    $errors.Add($message)
    Write-Host "[ENTRY ERROR] $message" -ForegroundColor Red
}

function Resolve-ScriptReference([string]$reference, [string]$sourceDirectory) {
    $normalized = $reference.Replace("/", [IO.Path]::DirectorySeparatorChar)
    if ($normalized.StartsWith("MOD" + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        return [IO.Path]::GetFullPath((Join-Path $modRoot $normalized.Substring(4)))
    }
    return [IO.Path]::GetFullPath((Join-Path $sourceDirectory $normalized))
}

function Test-InRoot([string]$fullPath) {
    return $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
}

function Visit-Lua([string]$filePath, [string[]]$chain) {
    $fullPath = [IO.Path]::GetFullPath($filePath)
    $relative = Get-RelativePath $fullPath
    if (-not (Test-InRoot $fullPath)) {
        Add-Error ("Entry closure escapes mod root: " + (($chain + $relative) -join " -> "))
        return
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Add-Error ("Missing Lua entry/include: " + (($chain + $relative) -join " -> "))
        return
    }
    if ($state[$fullPath] -eq "visiting") {
        Add-Error ("Include cycle: " + (($chain + $relative) -join " -> "))
        return
    }
    if ($state[$fullPath] -eq "done") {
        return
    }
    $state[$fullPath] = "visiting"
    $content = [IO.File]::ReadAllText($fullPath)
    $graph[$fullPath] = @()
    $includeMatches = [regex]::Matches($content, '(?m)^\s*#include\s+"([^"]+)"')
    foreach ($match in $includeMatches) {
        $include = $match.Groups[1].Value
        if ($include.Replace("/", "\").StartsWith("script\include\", [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $candidate = Resolve-ScriptReference $include (Split-Path -Parent $fullPath)
        $graph[$fullPath] += $candidate
        Visit-Lua $candidate ($chain + $relative)
    }
    $state[$fullPath] = "done"
}

$xmlFiles = New-Object System.Collections.Generic.List[object]
$rootMainXml = Join-Path $modRoot "main.xml"
$rootEscortXml = Join-Path $modRoot "riddle_escort.xml"
foreach ($rootXml in @($rootMainXml, $rootEscortXml)) {
    if (Test-Path -LiteralPath $rootXml -PathType Leaf) {
        $xmlFiles.Add((Get-Item -LiteralPath $rootXml))
    }
}
$prefabRoot = Join-Path $modRoot "prefabs"
if (Test-Path -LiteralPath $prefabRoot -PathType Container) {
    foreach ($prefabXml in @(Get-ChildItem -LiteralPath $prefabRoot -Filter *.xml -Recurse -File)) {
        $xmlFiles.Add($prefabXml)
    }
}

foreach ($xml in $xmlFiles) {
    try {
        $xmlDocument = New-Object System.Xml.XmlDocument
        $xmlDocument.PreserveWhitespace = $true
        $xmlDocument.Load($xml.FullName)
    }
    catch {
        Add-Error ("Malformed XML entry source: " + (Get-RelativePath $xml.FullName) + ": " + $_.Exception.Message)
        continue
    }
    foreach ($node in @($xmlDocument.SelectNodes("//script[@file]"))) {
        $reference = $node.GetAttribute("file")
        if ([string]::IsNullOrWhiteSpace($reference)) { continue }
        $candidate = Resolve-ScriptReference $reference $xml.DirectoryName
        $entries.Add($candidate)
    }
}

$entries.Add((Join-Path $modRoot "main.lua"))
foreach ($shipMain in @(Get-ChildItem -LiteralPath $modRoot -Filter shipMain.lua -Recurse -File)) {
    $entries.Add($shipMain.FullName)
}

$uniqueEntries = @($entries | Sort-Object -Unique)
foreach ($entry in $uniqueEntries) {
    Visit-Lua $entry @()
}

if ($errors.Count -gt 0) {
    Write-Host "Check failed: $($errors.Count) entry closure issue(s)." -ForegroundColor Red
    exit 1
}

Write-Host ("Check complete: " + $uniqueEntries.Count + " entry points, " + $graph.Count + " Lua files in closure, 0 issue(s)")
Write-Host "OK - all XML script entries and explicit ship entry points have valid local include closures." -ForegroundColor Green
exit 0
