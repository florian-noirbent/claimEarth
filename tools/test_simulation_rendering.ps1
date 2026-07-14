$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
& $godot --path "$PSScriptRoot\.." --rendering-driver opengl3 --resolution 1280x720 --disable-vsync --script res://tools/test_simulation_rendering.gd
exit $LASTEXITCODE
