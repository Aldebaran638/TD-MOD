# Teardown official API validation entry point.

param(
    [string]$Path = ".\Content Mod 2\script",
    [string]$LuaExecutable = "",
    [string]$TeardownDataPath = "",
    [switch]$Verbose
)

$checker = Join-Path $PSScriptRoot "check-lua.ps1"
if ($Verbose) {
    & $checker -Path $Path -Mode Api -LuaExecutable $LuaExecutable -TeardownDataPath $TeardownDataPath -Verbose
}
else {
    & $checker -Path $Path -Mode Api -LuaExecutable $LuaExecutable -TeardownDataPath $TeardownDataPath
}
exit $LASTEXITCODE
