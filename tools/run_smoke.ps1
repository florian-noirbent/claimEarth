$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
& $godot --headless --path "$PSScriptRoot\.." --quit-after 2
exit $LASTEXITCODE
