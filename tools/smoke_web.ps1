$ErrorActionPreference = "Stop"

& "$PSScriptRoot\export_web.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

$buildDir = Join-Path $PSScriptRoot "..\build\web"
$indexPath = Join-Path $buildDir "index.html"
$jsAsset = Get-ChildItem -Path $buildDir -Filter *.js | Select-Object -First 1
$wasmAsset = Get-ChildItem -Path $buildDir -Filter *.wasm | Select-Object -First 1
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
	throw "Web smoke failed: index.html was not exported."
}
if ($null -eq $jsAsset -or $null -eq $wasmAsset) {
	throw "Web smoke failed: exported JavaScript or WebAssembly payload is missing."
}

& "$PSScriptRoot\smoke_exported_game.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

$serverId = & "$PSScriptRoot\serve_web.ps1"
try {
	Start-Sleep -Seconds 2
	$index = Invoke-WebRequest -Uri "http://127.0.0.1:8936/index.html" -UseBasicParsing
	if ($index.StatusCode -ne 200) {
		throw "Web smoke failed to load index.html"
	}
	$js = Invoke-WebRequest -Uri ("http://127.0.0.1:8936/{0}" -f $jsAsset.Name) -UseBasicParsing
	$wasm = Invoke-WebRequest -Uri ("http://127.0.0.1:8936/{0}" -f $wasmAsset.Name) -UseBasicParsing
	if ($js.StatusCode -ne 200 -or $wasm.StatusCode -ne 200) {
		throw "Web smoke failed to load exported payloads."
	}
	@(
		"index=$($index.StatusCode)"
		"js=$($js.StatusCode) $($jsAsset.Name)"
		"wasm=$($wasm.StatusCode) $($wasmAsset.Name)"
	) | Set-Content -LiteralPath (Join-Path $buildDir "export-status.txt")
}
finally {
	& "$PSScriptRoot\stop_web_server.ps1" -ProcessId ([int]$serverId)
}
