# Verifies the normalized weapon module directory layout and include boundaries.

param([string]$Path = ".\Content Mod 2")

$ErrorActionPreference = "Stop"
$issues = 0
function Add-Issue { param([string]$Message); Write-Host "[WEAPON DIRECTORY ERROR] $Message" -ForegroundColor Red; $script:issues++ }
function Require-Path { param([string]$Relative, [bool]$Directory = $false); $candidate = Join-Path $script:root $Relative; $kind = if ($Directory) { "Container" } else { "Leaf" }; if (-not (Test-Path -LiteralPath $candidate -PathType $kind)) { Add-Issue "missing $kind`: $Relative" } }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Write-Host "[ERROR] Mod directory does not exist: $Path" -ForegroundColor Red; exit 1 }
$root = (Resolve-Path -LiteralPath $Path).Path

foreach ($directory in @(
    "script\weapon\shared\targeting",
    "script\weapon\client\runtime",
    "script\weapon\client\interaction",
    "script\weapon\client\behavior",
    "script\weapon\client\slot",
    "script\weapon\client\presentation",
    "script\weapon\server\runtime",
    "script\weapon\server\behavior",
    "script\weapon\server\slot",
    "script\weapon\server\network"
)) { Require-Path $directory $true }

$clientBootstrap = Join-Path $root "script\weapon\client\bootstrap.lua"
$serverBootstrap = Join-Path $root "script\weapon\server\bootstrap.lua"
foreach ($file in @($clientBootstrap, $serverBootstrap)) { if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Add-Issue "missing bootstrap: $file" } }

foreach ($obsolete in @(
    "script\weapon\common",
    "script\weapon\client\common",
    "script\weapon\client\config_ui",
    "script\weapon\client\guided",
    "script\weapon\client\slots",
    "script\weapon\server\common",
    "script\weapon\server\behaviors",
    "script\weapon\server\guided",
    "script\weapon\server\slots",
    "script\weapon\server\slots\x\tachyon_lance",
    "script\weapon\server\slots\l\kinetic_artillery",
    "script\weapon\server\slots\h\gamma_strike_craft"
)) { if (Test-Path -LiteralPath (Join-Path $root $obsolete)) { Add-Issue "obsolete directory remains: $obsolete" } }

$allLua = Get-ChildItem -LiteralPath (Join-Path $root "script\weapon") -Filter "*.lua" -Recurse
foreach ($file in $allLua) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('/', '\')
    if ($relative -match '\\(tachyon_lance|kinetic_artillery|gamma_strike_craft)\\') { Add-Issue "concrete weapon directory remains in module path: $relative" }
    if ($relative -match '^script\\weapon\\client\\interaction\\.*\\(tachyon_lance|kinetic_artillery|gamma_strike_craft)') { Add-Issue "concrete weapon name remains in client interaction path: $relative" }
    if ($relative -match '^script\\weapon\\server\\behavior\\.*\\(tachyon_lance|kinetic_artillery|gamma_strike_craft)') { Add-Issue "concrete weapon name remains in server behavior path: $relative" }
}

foreach ($file in @($clientBootstrap, $serverBootstrap)) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $text = [IO.File]::ReadAllText($file)
    if ($text -match 'client[\\/]common|server[\\/]common|behaviors[\\/]|client[\\/]guided|client[\\/]slots|server[\\/]guided|server[\\/]slots|#include\s+"(?:slots|guided)[\\/]') { Add-Issue "legacy include path remains in $file" }
}

Write-Host "=== Weapon Directory Structure Checker ===" -ForegroundColor Cyan
if ($issues -gt 0) { Write-Host "Check failed: $issues issue(s)." -ForegroundColor Red; exit 1 }
Write-Host "OK - weapon modules follow normalized responsibility and behavior boundaries." -ForegroundColor Green
exit 0
