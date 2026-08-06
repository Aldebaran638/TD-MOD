# Teardown XML syntax checker.

param([string]$Path = ".\Content Mod 2")

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Host "[ERROR] Directory does not exist: $Path" -ForegroundColor Red
    exit 1
}

$issues = 0
$root = (Resolve-Path -LiteralPath $Path).Path
$files = @(Get-ChildItem -LiteralPath $root -Recurse -Filter "*.xml" -File)

Write-Host "=== Teardown XML Syntax Checker ===" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $files) {
    try {
        [xml]$null = [IO.File]::ReadAllText($file.FullName)
    }
    catch {
        $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/')
        Write-Host "[XML SYNTAX ERROR] ${relative}: $($_.Exception.Message)" -ForegroundColor Red
        $issues++
    }
}

Write-Host "Check complete: $($files.Count) XML files, $issues syntax issue(s)." -ForegroundColor Cyan
if ($issues -gt 0) { exit 1 }
Write-Host "OK - All XML files are well-formed." -ForegroundColor Green
exit 0
