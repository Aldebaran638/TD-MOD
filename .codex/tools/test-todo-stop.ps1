$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$hookPath = Join-Path $repoRoot '.codex\hooks\check-todo-stop.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('cm2-todo-hook-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Assert-Equal([string]$name, $actual, $expected) {
    if ($actual -ne $expected) {
        throw "$name failed. Expected [$expected], got [$actual]."
    }
}

function Invoke-HookCase([string]$name, [object[]]$tasks, [bool]$expectBlock, [string]$expectedReason) {
    $path = Join-Path $tempRoot ($name + '.json')
    $document = [ordered]@{
        status_field = 'status'
        completion_statuses = @('finish', 'unable')
        tasks = $tasks
    }
    $document | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding utf8

    $output = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hookPath -TaskPath $path 2>&1 | Out-String).Trim()
    if ($expectBlock) {
        if ([string]::IsNullOrWhiteSpace($output)) {
            throw "$name expected a blocking JSON result, but hook output was empty."
        }
        $result = $output | ConvertFrom-Json
        Assert-Equal "$name decision" $result.decision 'block'
        if (-not [string]::IsNullOrWhiteSpace($expectedReason) -and $result.reason -notlike "*$expectedReason*") {
            throw "$name reason did not contain [$expectedReason]. Actual: $($result.reason)"
        }
    }
    else {
        Assert-Equal "$name output" $output ''
    }
}

try {
    Invoke-HookCase 'all-finish' @(
        [ordered]@{ id = 'TEST-1'; title = 'finished task'; status = 'finish' }
        [ordered]@{ id = 'TEST-2'; title = 'finished task'; status = 'finish' }
    ) $false ''

    Invoke-HookCase 'one-pending' @(
        [ordered]@{ id = 'TEST-1'; title = 'pending task'; status = 'not_started' }
        [ordered]@{ id = 'TEST-2'; title = 'later task'; status = 'finish' }
    ) $true 'TEST-1'

    Invoke-HookCase 'unable-is-allowed' @(
        [ordered]@{ id = 'TEST-1'; title = 'blocked but resolved'; status = 'unable' }
    ) $false ''

    Invoke-HookCase 'missing-status' @(
        [ordered]@{ id = 'TEST-1'; title = 'missing status' }
    ) $true 'TEST-1'

    $badPath = Join-Path $tempRoot 'malformed.json'
    '{not-json' | Set-Content -LiteralPath $badPath -Encoding utf8
    $badOutput = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hookPath -TaskPath $badPath 2>&1 | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($badOutput)) {
        throw 'malformed-json expected a blocking JSON result, but hook output was empty.'
    }
    $badResult = $badOutput | ConvertFrom-Json
    Assert-Equal 'malformed-json decision' $badResult.decision 'block'

    Write-Output 'todo-stop-hook-tests: PASS (5 cases)'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
