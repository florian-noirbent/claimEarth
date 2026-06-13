$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
$output = Join-Path $PSScriptRoot "..\build\web\index.html"
New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
& $godot --headless --path "$PSScriptRoot\.." --export-release Web $output
exit $LASTEXITCODE
