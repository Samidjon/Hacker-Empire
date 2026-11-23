# Runs the headless validation suite. Exit code 0 = everything passed.
# Usage:  .\tests\run_tests.ps1 -Godot "C:\path\to\Godot_v4.x_console.exe"
param(
    [Parameter(Mandatory = $true)][string]$Godot
)

$project = Split-Path -Parent $PSScriptRoot
$failed = $false

Write-Host "== Importing project ==" -ForegroundColor Cyan
& $Godot --headless --path $project --import | Out-Null

foreach ($scene in "res://tests/TestRunner.tscn", "res://tests/FlowTest.tscn") {
    Write-Host "== $scene ==" -ForegroundColor Cyan
    & $Godot --headless --path $project $scene
    if ($LASTEXITCODE -ne 0) { $failed = $true }
}

if ($failed) {
    Write-Host "TESTS FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
