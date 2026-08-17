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
    $pending.tasks[0].PSObject.Properties.Remove('unable_exception')
    Invoke-HookCase 'pending-verification' $pending $true 'Step 0.1'

    $regression = New-CompletedDocument
    $regression.tasks[5].verification_status = 'needs_regression'
    Invoke-HookCase 'needs-regression' $regression $true 'Step 1.1'

    $human = New-CompletedDocument
    $human.tasks[0].verification_status = 'human_visual_review'
    Invoke-HookCase 'human-review-terminal' $human $false ''

    $deferredVerification = New-CompletedDocument
    $deferredVerification.tasks[0].verification_status = 'pending'
    $deferredVerification.tasks[0] | Add-Member -NotePropertyName unable_exception -NotePropertyValue ([ordered]@{
        marker = 'ENVIRONMENT_BLOCKED'
        reason = 'The live run is blocked by the documented input desktop.'
        evidence = 'docs/evidence/hook-test-verification-environment.json'
        reviewed_by = 'human'
        reviewed_at = '2026-08-15T00:00:00+08:00'
    }) -Force
    Invoke-HookCase 'valid-pending-verification-exception' $deferredVerification $false ''

    $unable = New-CompletedDocument
    $unable.tasks[0].implementation_status = 'unable'
    $unable.tasks[0].verification_status = 'pending'
    $unable.tasks[0].PSObject.Properties.Remove('unable_exception')
    Invoke-HookCase 'historical-confirmed-unable' $unable $true 'unable_exception'

    $unconfirmed = New-CompletedDocument
    $unconfirmed.tasks[0].implementation_status = 'unable'
    $unconfirmed.tasks[0].verification_status = 'pending'
    $unconfirmed.tasks[0].PSObject.Properties.Remove('unable_exception')
    $unconfirmed.developer_confirmed_unable.task_ids = @($unconfirmed.developer_confirmed_unable.task_ids | Where-Object { [string]$_ -ne 'Step 0.1' })
    Invoke-HookCase 'old-allowlist-removed-unable' $unconfirmed $true 'unable_exception'

    $exception = New-CompletedDocument
    $exception.tasks[0].implementation_status = 'unable'
    $exception.tasks[0].verification_status = 'pending'
    $exception.developer_confirmed_unable.task_ids = @($exception.developer_confirmed_unable.task_ids | Where-Object { [string]$_ -ne 'Step 0.1' })
    $exception.tasks[0] | Add-Member -NotePropertyName unable_exception -NotePropertyValue ([ordered]@{
        marker = 'ENVIRONMENT_BLOCKED'
        reason = 'The live run hit a documented environment limitation.'
        evidence = 'docs/evidence/hook-test-environment.json'
        reviewed_by = 'human'
        reviewed_at = '2026-08-15T00:00:00+08:00'
    }) -Force
    Invoke-HookCase 'valid-unable-exception' $exception $false ''

    $incompleteException = New-CompletedDocument
    $incompleteException.tasks[0].implementation_status = 'unable'
    $incompleteException.tasks[0].verification_status = 'pending'
    $incompleteException.developer_confirmed_unable.task_ids = @($incompleteException.developer_confirmed_unable.task_ids | Where-Object { [string]$_ -ne 'Step 0.1' })
    $incompleteException.tasks[0] | Add-Member -NotePropertyName unable_exception -NotePropertyValue ([ordered]@{
        marker = 'ENVIRONMENT_BLOCKED'
        reason = 'Missing evidence fields must block stopping.'
    }) -Force
    Invoke-HookCase 'incomplete-unable-exception' $incompleteException $true 'unable_exception'

    $missing = New-CompletedDocument
    $missing.tasks[0].PSObject.Properties.Remove('verification')
    Invoke-HookCase 'missing-contract' $missing $true 'verification'

    $badPath = Join-Path $tempRoot 'malformed.json'
    '{not-json' | Set-Content -LiteralPath $badPath -Encoding utf8
    $badOutput = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hookPath -TaskPath $badPath 2>&1 | Out-String).Trim() | ConvertFrom-Json
    Assert-Equal 'malformed decision' $badOutput.decision 'block'

    Write-Output 'todo-stop-hook-tests: PASS (11 cases)'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
