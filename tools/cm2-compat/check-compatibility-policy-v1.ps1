# Static consistency checker for the public compatibility/deprecation policy.

param([string]$PolicyPath = "", [string]$FixturePath = "")
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($PolicyPath -eq "") { $PolicyPath = Join-Path $root "docs\compatibility-policy-v1.json" }
if ($FixturePath -eq "") { $FixturePath = Join-Path $root "docs\candidates\compatibility-policy-v1.fixture.json" }
$issues = New-Object System.Collections.Generic.List[string]
function Require([bool]$condition, [string]$message) { if (-not $condition) { [void]$issues.Add($message) } }
try { $policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json } catch { [void]$issues.Add("policy JSON is invalid: $($_.Exception.Message)") }
try { $fixtures = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json } catch { [void]$issues.Add("fixture JSON is invalid: $($_.Exception.Message)") }
if ($null -ne $policy) {
    Require ([string]$policy.schema -eq "cm2.compatibility-policy/1" -and [string]$policy.policyVersion -match '^1\.\d+\.\d+$') "policy identity/version is invalid"
    Require (@($policy.supportMatrix).Count -eq 5) "support matrix must cover exactly five public surfaces"
    $surfaces = @($policy.supportMatrix | ForEach-Object { [string]$_.surface })
    Require (((@($surfaces | Sort-Object) -join "|") -eq (@(@("source-envelope","package","core-api","sdk","build-format") | Sort-Object) -join "|"))) "support matrix surface set is incomplete"
    foreach ($row in @($policy.supportMatrix)) {
        foreach ($field in @("surface","write","minimum","maximumExclusive","unknownOptional","futureRequired")) { Require ([string]$row.$field -ne "") ("support matrix field missing: " + [string]$row.surface + "." + $field) }
        Require (@($row.read).Count -gt 0 -and [string]$row.futureRequired -eq "fail-fast") ("read/future policy invalid: " + [string]$row.surface)
    }
    Require ((@($policy.negotiation.order) -join "|") -eq "package|core-api|schema|build-format|sdk") "version negotiation order changed"
    Require ([string]$policy.negotiation.supportedCoreApiRange -eq ">=1.0.0 <2.0.0" -and [string]$policy.negotiation.supportedSdkRange -eq ">=1.0.0 <2.0.0") "Core/SDK support windows changed without a policy major"
    foreach ($level in @("unknownOptional","deprecatedAlias","missingRequired","futureRequired","unsupportedVersion","securitySensitiveUnknown")) { Require ([string]$policy.diagnosticLevels.$level -in @("warning","error")) ("diagnostic level missing: " + $level) }
    Require ([bool]$policy.readWritePolicy.migrationIdempotent -and [string]$policy.readWritePolicy.currentSchemaWrite -eq "single canonical v1 writer") "idempotent single-write policy is missing"
    Require ([string]$policy.readWritePolicy.inputMutation -eq "forbidden" -and [string]$policy.readWritePolicy.failedOutputOverwrite -eq "forbidden") "source/last-valid preservation policy is missing"
    foreach ($migration in @($policy.migrations)) {
        Require ([bool]$migration.idempotent -and [bool]$migration.singleWrite -and [string]$migration.status -eq "supported") ("migration contract invalid: " + [string]$migration.id)
        Require (Test-Path -LiteralPath (Join-Path $root ([string]$migration.tool)) -PathType Leaf) ("migration tool missing: " + [string]$migration.tool)
    }
    foreach ($entry in @($policy.deprecations)) {
        foreach ($field in @("id","introduced","deprecatedIn","deprecatedOn","removeAfter","removalEarliestDate","owner","replacement","level","readerStatus")) { Require ([string]$entry.$field -ne "") ("deprecation field missing: " + [string]$entry.id + "." + $field) }
        $deprecatedDate = [datetime]::MinValue; $removalDate = [datetime]::MinValue
        Require ([datetime]::TryParse([string]$entry.deprecatedOn, [ref]$deprecatedDate) -and [datetime]::TryParse([string]$entry.removalEarliestDate, [ref]$removalDate) -and $removalDate -gt $deprecatedDate) ("deprecation dates invalid: " + [string]$entry.id)
        Require ([string]$entry.owner -notmatch '___|placeholder' -and [string]$entry.writerRemoval.status -eq "verified" -and [string]$entry.writerRemoval.evidence -ne "") ("writer removal evidence invalid: " + [string]$entry.id)
        Require ([string]$entry.readerRemoval.status -eq "not-eligible" -and [string]$entry.readerRemoval.evidence -ne "") ("reader retention/removal evidence invalid: " + [string]$entry.id)
    }
    foreach ($field in @("ownerRequired","deprecatedDateRequired","removalDateRequired","replacementRequired","writerRemovalEvidenceRequired","readerRemovalEvidenceRequired","noSilentRemoval")) { Require ([bool]$policy.removalLedger.$field) ("removal ledger requirement missing: " + $field) }
    $resolver = Join-Path $root ([string]$policy.publicIntegration.resolver); $validator = Join-Path $root ([string]$policy.publicIntegration.packageValidator)
    Require (Test-Path -LiteralPath $resolver -PathType Leaf) "public compatibility resolver is missing"
    Require (Test-Path -LiteralPath $validator -PathType Leaf) "public PackageManifest validator is missing"
    if (Test-Path -LiteralPath $validator -PathType Leaf) {
        $validatorText = Get-Content -Raw -LiteralPath $validator
        Require ($validatorText.Contains("resolve-compatibility-v1.ps1") -and $validatorText.Contains("compatibilityPolicyHash")) "PackageManifest validator is not wired to the public policy resolver/hash"
    }
}
if ($null -ne $fixtures) {
    foreach ($name in @("validV0Effect","validV0Weapon","validV0Package","missingRequired","unknownOptional","futureRequired","securitySensitive","unsupportedOld")) { Require ($null -ne $fixtures.PSObject.Properties[$name]) ("fixture missing: " + $name) }
}
if ($issues.Count -gt 0) { Write-Error ("Compatibility policy check failed:`n - " + ($issues -join "`n - ")); exit 1 }
Write-Host "Compatibility policy v1 passed: five-surface matrix, public resolver integration, canonical migrations and dated deprecation ledger are consistent." -ForegroundColor Green
exit 0
