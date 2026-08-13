# Regression test for developer-confirmed unable handling.

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hook = Join-Path $PSScriptRoot 'check-todo-stop.ps1'
$source = Join-Path $root 'TEARDOWN_SHIP_PLATFORM_TODO.json'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('cm2-hook-unconfirmed-' + [Guid]::NewGuid().ToString('N') + '.json')
function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) { throw ('Todo hook developer-confirmation test failed: ' + $message) }
    Write-Host ('[PASS] ' + $message) -ForegroundColor Green
}
try {
    $document = Get-Content -Raw -LiteralPath $source | ConvertFrom-Json
    $document.developer_confirmed_unable.task_ids = @($document.developer_confirmed_unable.task_ids | Where-Object { [string]$_ -ne 'Step 11.6' })
    [IO.File]::WriteAllText($temp, ($document | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook -TaskPath $temp
    Assert-True ([string]$output -match 'block' -and [string]$output -match 'Step 11\.6') 'unconfirmed unable is blocked and requested'
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook -TaskPath $source
    Assert-True (@($output).Count -eq 0) 'all developer-confirmed unable tasks allow stop'
    Write-Host 'Todo hook developer-confirmation regression passed.' -ForegroundColor Green
    exit 0
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
}
