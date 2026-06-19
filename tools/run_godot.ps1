$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$godot = & (Join-Path $PSScriptRoot "resolve_godot.ps1")

& $godot --path $projectRoot
