$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
& $godot --headless --path "$PSScriptRoot\.." --script res://tools/benchmark_terrain_current.gd
exit $LASTEXITCODE
