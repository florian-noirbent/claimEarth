param(
	[switch]$Debug
)

$ErrorActionPreference = "Stop"
$godot = & "$PSScriptRoot\resolve_godot.ps1"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$presetPath = Join-Path $projectRoot "export_presets.cfg"
$presetText = Get-Content -LiteralPath $presetPath -Raw
$webPresetMatch = [regex]::Match(
	$presetText,
	'(?ms)^\[preset\.\d+\]\s+.*?^name="([^"]+)"\s+platform="Web"'
)
if (-not $webPresetMatch.Success) {
	throw "No Web export preset was found in export_presets.cfg."
}

$presetName = $webPresetMatch.Groups[1].Value
$output = Join-Path $projectRoot "build\web\index.html"
New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
$exportFlag = if ($Debug) { "--export-debug" } else { "--export-release" }
Write-Host "Exporting Web preset '$presetName' with $godot"
& $godot --headless --path $projectRoot $exportFlag $presetName $output
exit $LASTEXITCODE
