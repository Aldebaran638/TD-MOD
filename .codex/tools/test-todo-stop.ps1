$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$hookPath = Join-Path $repoRoot '.codex\hooks\check-todo-stop.ps1'
$sourcePath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.json'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('cm2-todo-hook-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Assert-Equal([string]$name, $actual, $expected) {
    if ($actual -ne $expected) { throw "$name failed. Expected [$expected], got [$actual]." }
}

function New-CompletedDocument {
    $document = Get-Content -Raw -Encoding utf8 -LiteralPath $sourcePath | ConvertFrom-Json
    foreach ($task in @($document.tasks)) {
        $task.implementation_status = 'finish'
        $task.verification_status = 'verified'
    }
    return $document
}

function Invoke-HookCase([string]$name, $document, [bool]$expectBlock, [string]$expectedReason) {
    $path = Join-Path $tempRoot ($name + '.json')
    [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
    $output = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hookPath -TaskPath $path 2>&1 | Out-String).Trim()
    if ($expectBlock) {
        if ([string]::IsNullOrWhiteSpace($output)) { throw "$name expected blocking JSON, but output was empty." }
        $result = $output | ConvertFrom-Json
        Assert-Equal "$name decision" $result.decision 'block'
        if ($result.reason -notlike "*$expectedReason*") { throw "$name reason did not contain [$expectedReason]. Actual: $($result.reason)" }
    } else {
        Assert-Equal "$name output" $output ''
    }
}

try {
    Invoke-HookCase 'all-verified' (New-CompletedDocument) $false ''

    $pending = New-CompletedDocument
    $pending.tasks[0].verification_status = 'pending'
    Invoke-HookCase 'pending-verification' $pending $true 'Step 0.1'

    $regression = New-CompletedDocument
    $regression.tasks[5].verification_status = 'needs_regression'
    Invoke-HookCase 'needs-regression' $regression $true 'Step 1.1'

    $human = New-CompletedDocument
    $human.tasks[0].verification_status = 'human_visual_review'
    Invoke-HookCase 'human-review-terminal' $human $false ''

    $unable = New-CompletedDocument
    $unable.tasks[0].implementation_status = 'unable'
    $unable.tasks[0].verification_status = 'pending'
    Invoke-HookCase 'confirmed-unable' $unable $false ''

    $unconfirmed = New-CompletedDocument
    $unconfirmed.tasks[0].implementation_status = 'unable'
    $unconfirmed.tasks[0].verification_status = 'pending'
    $unconfirmed.developer_confirmed_unable.task_ids = @($unconfirmed.developer_confirmed_unable.task_ids | Where-Object { [string]$_ -ne 'Step 0.1' })
    Invoke-HookCase 'unconfirmed-unable' $unconfirmed $true 'developer confirmation'

    $missing = New-CompletedDocument
    $missing.tasks[0].PSObject.Properties.Remove('verification')
    Invoke-HookCase 'missing-contract' $missing $true 'verification'

    $badPath = Join-Path $tempRoot 'malformed.json'
    '{not-json' | Set-Content -LiteralPath $badPath -Encoding utf8
    $badOutput = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hookPath -TaskPath $badPath 2>&1 | Out-String).Trim() | ConvertFrom-Json
    Assert-Equal 'malformed decision' $badOutput.decision 'block'

    Write-Output 'todo-stop-hook-tests: PASS (8 cases)'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
