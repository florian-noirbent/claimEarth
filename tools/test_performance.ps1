$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
& $godot --headless --path "$PSScriptRoot\.." --script res://addons/gut/gut_cmdln.gd -gdir=res://tests/performance -ginclude_subdirs -gexit
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& "$PSScriptRoot\test_simulation_rendering.ps1"
exit $LASTEXITCODE
