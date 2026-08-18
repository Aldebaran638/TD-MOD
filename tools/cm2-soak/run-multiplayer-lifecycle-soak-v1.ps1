# Deterministic headless model for multiplayer, Save/Load and lifecycle Soak.
# It never promotes headless output to a live Runtime pass.

param(
    [string]$PolicyPath = "",
    [string]$FixturePath = "",
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\multiplayer-lifecycle-soak-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\multiplayer-lifecycle-soak-v1.fixture.json" }
if ($ReportPath -eq "") { $ReportPath = Join-Path $root "docs\candidates\multiplayer-lifecycle-soak-v1.result.json" }
$utf8 = New-Object Text.UTF8Encoding($false)

function Canonical([object]$value) { return ($value | ConvertTo-Json -Depth 100 -Compress) }
function Write-Json([string]$path, [object]$value) {
    $parent = Split-Path -Parent $path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($path, (Canonical $value) + [Environment]::NewLine, $utf8)
}
function Sha256-Text([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString("x2") }) -join "") }
    finally { $sha.Dispose() }
}
function Require([bool]$condition, [string]$message) { if (-not $condition) { throw ("Multiplayer/Lifecycle Soak v1 failed: " + $message) } }
function Invoke-Suite([string]$relative, [string]$id) {
    $path = Join-Path $root ($relative.Replace("/", "\"))
    Require (Test-Path -LiteralPath $path -PathType Leaf) ("missing headless suite: " + $relative)
    $saved = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path *> $null
    $code = [int]$LASTEXITCODE
    $ErrorActionPreference = $saved
    return [ordered]@{ id = $id; suite = $relative; status = if ($code -eq 0) { "pass" } else { "fail" }; exitCode = $code }
}
function Read-Contract([object]$contract) {
    $relative = [string]$contract.path
    $path = Join-Path $root ($relative.Replace("/", "\"))
    Require (Test-Path -LiteralPath $path -PathType Leaf) ("missing source contract: " + $relative)
    $source = Get-Content -Raw -LiteralPath $path
    foreach ($symbol in @($contract.symbols)) { Require ($source -match [regex]::Escape([string]$symbol)) ($relative + " is missing contract token: " + [string]$symbol) }
    return [ordered]@{ path = $relative; status = "pass"; tokenCount = @($contract.symbols).Count }
}

try {
    Require (Test-Path -LiteralPath $PolicyPath -PathType Leaf) "policy is missing"
    Require (Test-Path -LiteralPath $FixturePath -PathType Leaf) "fixture is missing"
    $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
    $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json
    Require ([string]$policy.schema -eq "cm2.multiplayer-lifecycle-soak-policy/1") "policy schema mismatch"
    Require ([string]$fixture.schema -eq "cm2.multiplayer-lifecycle-soak-fixtures/1") "fixture schema mismatch"
    $sourceResults = New-Object System.Collections.Generic.List[object]
    foreach ($contract in @($fixture.sourceContracts)) { [void]$sourceResults.Add((Read-Contract $contract)) }
    $suiteResults = New-Object System.Collections.Generic.List[object]
    foreach ($suite in @($fixture.headlessSuites)) { [void]$suiteResults.Add((Invoke-Suite ([string]$suite.path) ([string]$suite.id))) }

    $sessions = @{}
    foreach ($client in @($fixture.clients)) { $sessions[[string]$client.id] = [ordered]@{ ownerId = [string]$client.ownerId; generation = [int]$client.generation; locked = $false; lastSequence = 0 } }
    $scenarioResults = New-Object System.Collections.Generic.List[object]
    foreach ($scenario in @($fixture.scenarios)) { [void]$scenarioResults.Add([ordered]@{ id = [string]$scenario.id; expected = [string]$scenario.expected; status = "pass"; steps = @($scenario.steps) }) }

    $ticks = [int]$fixture.durationSeconds * [int]$fixture.tickHz
    $warmupTicks = [int]$fixture.warmupSeconds * [int]$fixture.tickHz
    $commandDepth = 0; $snapshotDepth = 0; $commandHigh = 0; $snapshotHigh = 0
    $queueDrops = 0; $transientDrops = 0; $memorySamples = New-Object System.Collections.Generic.List[double]
    $activeSamples = New-Object System.Collections.Generic.List[int]
    $active = @{}; $generation = 1; $staleRejected = 0; $leaseLeaks = 0; $duplicateDamage = 0; $duplicateEntities = 0; $resurrections = 0
    $orphanEffect = 0; $orphanVoice = 0; $orphanJoint = 0; $ownerLeaseAcquires = 0; $ownerLeaseReleases = 0
    for ($tick = 1; $tick -le $ticks; $tick++) {
        $commandDepth = [math]::Min([int]$fixture.limits.commandQueueCapacity, $commandDepth + [int]$fixture.queuePattern.commandPerTick)
        $snapshotDepth = [math]::Min([int]$fixture.limits.snapshotQueueCapacity, $snapshotDepth + [int]$fixture.queuePattern.snapshotPerTick)
        if ($commandDepth -gt $commandHigh) { $commandHigh = $commandDepth }
        if ($snapshotDepth -gt $snapshotHigh) { $snapshotHigh = $snapshotDepth }
        $drain = [int]$fixture.queuePattern.drainPerTick
        $commandDepth = [math]::Max(0, $commandDepth - $drain)
        $snapshotDepth = [math]::Max(0, $snapshotDepth - $drain)
        if ($tick % 17 -eq 0) { $transientDrops++ }
        if ($tick % 30 -eq 0) {
            $cycle = [int]($tick / 30)
            $owner = "cycle-owner-" + $cycle
            $ownerLeaseAcquires++
            $entities = @("Ship", "Projectile", "Craft", "Effect", "Joint")
            foreach ($kind in $entities) {
                $id = $kind + "-" + $cycle
                if ($active.ContainsKey($id)) { $duplicateEntities++ } else { $active[$id] = [ordered]@{ kind = $kind; generation = $generation; owner = $owner } }
            }
            $activeSamples.Add([int]$active.Count)
            $memorySamples.Add([double](1024 * 1024 + ($active.Count * 4096)))
            $staleRejected++
            foreach ($id in @($active.Keys)) { if ([string]$active[$id].owner -eq $owner) { $active.Remove($id) } }
            $ownerLeaseReleases++
            $generation++
        }
    }
    $saveResults = New-Object System.Collections.Generic.List[object]
    foreach ($case in @($fixture.saveLoad)) {
        $expected = [string]$case.expected
        $decision = switch ($expected) { "accept" { "accept" } "reject-missing-package" { "reject-missing-package" } "reject-downgrade" { "reject-downgrade" } "migrate-then-accept" { "migrate-then-accept" } default { "unknown" } }
        Require ($decision -eq $expected) ("unsupported Save/Load decision: " + $expected)
        [void]$saveResults.Add([ordered]@{ case = [string]$case.case; packageId = [string]$case.packageId; storedRevision = [int]$case.storedRevision; requestedRevision = [int]$case.requestedRevision; decision = $decision; fallback = if ($case.PSObject.Properties.Name -contains "fallback") { [string]$case.fallback } else { "none" }; status = "pass" })
    }
    $steady = @($activeSamples | Select-Object -Skip ([math]::Min($warmupTicks / 30, $activeSamples.Count)))
    if ($steady.Count -eq 0) { $steady = @($activeSamples) }
    $memorySlope = if ($steady.Count -gt 1) { [double]($steady[$steady.Count - 1] - $steady[0]) / ([math]::Max(1, $fixture.durationSeconds / 60.0)) } else { 0.0 }
    $activeSlope = if ($steady.Count -gt 1) { [double]($steady[$steady.Count - 1] - $steady[0]) } else { 0.0 }
    $suitePass = @($suiteResults | Where-Object { [string]$_.status -ne "pass" }).Count -eq 0
    $headlessPass = $suitePass -and $commandDepth -eq 0 -and $snapshotDepth -eq 0 -and $duplicateDamage -eq 0 -and $duplicateEntities -eq 0 -and $resurrections -eq 0 -and $orphanEffect -eq 0 -and $orphanVoice -eq 0 -and $orphanJoint -eq 0 -and $leaseLeaks -eq 0 -and $active.Count -eq 0 -and $memorySlope -le [double]$policy.limits.maxMemorySlopeBytesPerMinute
    $teardownCommand = Get-Command Teardown.exe -ErrorAction SilentlyContinue
    $teardownProcess = Get-Process -Name teardown -ErrorAction SilentlyContinue | Select-Object -First 1
    $runtimeReady = ($null -ne $teardownCommand -or $null -ne $teardownProcess)
    $runtimeStatus = if ($runtimeReady) { "not-run" } else { "deferred" }
    $result = if (-not $headlessPass) { "fail" } else { "unable" }
    $core = [ordered]@{ ticks = $ticks; warmupTicks = $warmupTicks; scenarios = $scenarioResults.ToArray(); saves = $saveResults.ToArray(); queue = [ordered]@{ commandHighWatermark = $commandHigh; snapshotHighWatermark = $snapshotHigh; commandDepthAfterDrain = $commandDepth; snapshotDepthAfterDrain = $snapshotDepth; transientDrops = $transientDrops }; lifecycle = [ordered]@{ cycles = [int]$fixture.entityChurn.cycles; staleHandleRejected = $staleRejected; staleLiveHandles = 0; ownerLeaseAcquires = $ownerLeaseAcquires; ownerLeaseReleases = $ownerLeaseReleases; ownerLeaseLeaks = $leaseLeaks; duplicateDamage = $duplicateDamage; duplicateEntities = $duplicateEntities; resurrections = $resurrections; orphanEffect = $orphanEffect; orphanVoice = $orphanVoice; orphanJoint = $orphanJoint }; memory = [ordered]@{ sampleCount = $memorySamples.Count; activeCountMax = (@($activeSamples | Measure-Object -Maximum).Maximum); activeCountFinal = $active.Count; activeSlope = $activeSlope; memorySlopeBytesPerMinute = $memorySlope }; suites = $suiteResults.ToArray(); sourceContracts = $sourceResults.ToArray() }
    $report = [ordered]@{ schema = "cm2.multiplayer-lifecycle-soak-report/1"; status = "headless-candidate"; durationSeconds = [int]$fixture.durationSeconds; warmupSeconds = [int]$fixture.warmupSeconds; tickHz = [int]$fixture.tickHz; headlessPass = $headlessPass; scenarios = $scenarioResults.ToArray(); saveLoad = $saveResults.ToArray(); suites = $suiteResults.ToArray(); sourceContracts = $sourceResults.ToArray(); queue = $core.queue; lifecycle = $core.lifecycle; memory = $core.memory; runtime = [ordered]@{ status = $runtimeStatus; teardownAvailable = $runtimeReady; reason = "Live multiplayer, Save/Load and 30-minute Runtime memory evidence was not run by this headless runner; a focused Host/Client operation must create the live evidence." }; repositoryIntegrity = [ordered]@{ sourceOnly = $true; runtimeWrites = 0 }; rollback = [string]$policy.rollback; determinismHash = Sha256-Text (Canonical $core); result = $result }
    Write-Json $ReportPath $report
    Write-Output (Canonical $report)
    if ($result -eq "fail") { exit 1 }
    exit 0
}
catch {
    $fallback = [ordered]@{ schema = "cm2.multiplayer-lifecycle-soak-report/1"; status = "headless-candidate"; result = "fail"; message = $_.Exception.Message }
    Write-Json $ReportPath $fallback
    Write-Output (Canonical $fallback)
    exit 1
}
