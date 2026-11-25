param([Parameter(Mandatory)][string]$Godot)
$ErrorActionPreference = 'Stop'
$engine = (Resolve-Path -LiteralPath $Godot).Path
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('the-last-current-' + [Guid]::NewGuid())
$before = @($env:APPDATA, $env:LOCALAPPDATA, $env:LAST_CURRENT_TEST_ROOT)
try {
    [void][IO.Directory]::CreateDirectory($testRoot)
    $env:APPDATA = $testRoot
    $env:LOCALAPPDATA = $testRoot
    $env:LAST_CURRENT_TEST_ROOT = $testRoot
    & $engine --headless --path $project --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    & $engine --headless --path $project --script res://tests/career_smoke.gd
    if ($LASTEXITCODE -ne 0) { throw 'Career test failed' }
} finally {
    $env:APPDATA, $env:LOCALAPPDATA, $env:LAST_CURRENT_TEST_ROOT = $before
}
