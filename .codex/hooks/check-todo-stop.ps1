param(
    [string]$TaskPath
)

$ErrorActionPreference = 'Stop'

function Write-Continuation([string]$reason) {
    [ordered]@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress
}

function Test-UnableException($task, $policy) {
    if ($null -eq $policy -or $policy.enabled -ne $true) { return $false }
    $field = if ([string]::IsNullOrWhiteSpace([string]$policy.field)) { 'unable_exception' } else { [string]$policy.field }
    $property = $task.PSObject.Properties[$field]
    if ($null -eq $property -or $null -eq $property.Value -or $property.Value -is [Array]) { return $false }

    $exception = $property.Value
    $allowedMarkers = @($policy.allowed_markers | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $requiredFields = @($policy.required_fields | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($allowedMarkers.Count -eq 0 -or $requiredFields.Count -eq 0) { return $false }

    $markerProperty = $exception.PSObject.Properties['marker']
    if ($null -eq $markerProperty -or [string]::IsNullOrWhiteSpace([string]$markerProperty.Value) -or $allowedMarkers -notcontains [string]$markerProperty.Value) {
        return $false
    }
    foreach ($requiredField in $requiredFields) {
        $requiredProperty = $exception.PSObject.Properties[$requiredField]
        if ($null -eq $requiredProperty -or [string]::IsNullOrWhiteSpace([string]$requiredProperty.Value)) { return $false }
    }
    return $true
}

try {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    if ([string]::IsNullOrWhiteSpace($TaskPath)) {
        $TaskPath = Join-Path $repoRoot 'TEARDOWN_SHIP_PLATFORM_TODO.json'
    }
    if (-not (Test-Path -LiteralPath $TaskPath -PathType Leaf)) {
        Write-Continuation("CM2 Todo gate cannot find $TaskPath. Restore the executable plan before stopping.")
        exit 0
    }

    $validator = Join-Path $repoRoot '.codex\skills\teardown-autonomous-testing\scripts\validate_todo_plan.py'
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        Write-Continuation("CM2 Todo gate cannot find its fail-closed validator at $validator.")
        exit 0
    }
    $validation = (& python $validator $TaskPath --quiet 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        Write-Continuation("CM2 Todo gate rejected the executable plan: $validation")
        exit 0
    }

    $document = Get-Content -LiteralPath $TaskPath -Raw -Encoding utf8 | ConvertFrom-Json
    $tasks = @($document.tasks)
    $completionStatuses = @($document.completion_statuses)
    $verificationCompletion = @($document.verification_completion_statuses)
    $unableExceptionPolicy = $document.unable_exception_policy

    $unfinished = @($tasks | Where-Object {
        $implementation = [string]$_.implementation_status
        $verification = [string]$_.verification_status
        $unableExceptionValid = Test-UnableException $_ $unableExceptionPolicy
        $implementationIncomplete = $implementation -notin $completionStatuses
        $unableWithoutException = $implementation -eq 'unable' -and -not $unableExceptionValid
        $verificationIncomplete = $implementation -eq 'finish' -and $verification -notin $verificationCompletion
        $implementationIncomplete -or $unableWithoutException -or $verificationIncomplete
    })
    if ($unfinished.Count -eq 0) { exit 0 }

    $next = $unfinished[0]
    $reason = "CM2 executable Todo gate: $($unfinished.Count) task(s) still require implementation or verification. An implementation_status=unable task must be changed to finish unless it has a complete task-level unable_exception special marker with policy-approved marker, reason, evidence, reviewer and review time. Historical developer_confirmed_unable entries do not allow stopping. Continue with $($next.id) $($next.title) (implementation=$($next.implementation_status), verification=$($next.verification_status), automation=$($next.verification.automation_level)). Validate its embedded contract, execute the declared profiles/eyes/hands, persist evidence and regression, then update the independent statuses."
    Write-Continuation($reason)
    exit 0
}
catch {
    Write-Continuation("CM2 Todo gate failed closed: $($_.Exception.Message). Fix the executable task plan or hook before stopping.")
    exit 0
}
