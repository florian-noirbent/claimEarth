$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
& $godot --headless --path "$PSScriptRoot\.." --script res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
exit $LASTEXITCODE
