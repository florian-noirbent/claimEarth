$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
& $godot --headless --editor --path "$PSScriptRoot\.." --import
exit $LASTEXITCODE
