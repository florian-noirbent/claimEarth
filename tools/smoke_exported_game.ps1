$ErrorActionPreference = "Stop"

$godot = & "$PSScriptRoot\resolve_godot.ps1"
$buildDir = Join-Path $PSScriptRoot "..\build\web"
$packPath = Join-Path $buildDir "index.pck"
if (-not (Test-Path -LiteralPath $packPath -PathType Leaf)) {
	throw "Exported-game smoke failed: build/web/index.pck does not exist. Export the Web build first."
}

$packPath = (Resolve-Path -LiteralPath $packPath).Path
Write-Host "Starting exported-game smoke from $packPath"
$exitCode = 1
Push-Location $buildDir
try {
	& $godot `
		--headless `
		--main-pack $packPath `
		--script res://tests/export/exported_start_smoke.gd
	$exitCode = $LASTEXITCODE
}
finally {
	Pop-Location
}

exit $exitCode
