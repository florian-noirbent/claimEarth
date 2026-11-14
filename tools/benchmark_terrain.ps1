$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot/resolve_godot.ps1"
# The terrain simulation runs on the GPU, so the benchmark needs a real renderer.
& $godot --path "$PSScriptRoot/.." --rendering-driver opengl3 --resolution 1280x720 --disable-vsync --script res://tools/benchmark_terrain_current.gd
exit $LASTEXITCODE
