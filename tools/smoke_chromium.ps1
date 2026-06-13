$ErrorActionPreference = "Stop"

& "$PSScriptRoot\export_web.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

$chromeCandidates = @(
	"C:\Program Files\Google\Chrome\Application\chrome.exe",
	"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
$chromePath = @($chromeCandidates)[0]

if ([string]::IsNullOrWhiteSpace($chromePath)) {
	throw "Chrome was not found for the Chromium smoke test."
}

$serverId = & "$PSScriptRoot\serve_web.ps1"
$screenshotPath = Join-Path $PSScriptRoot "..\build\web\chromium-smoke.png"
$stderrPath = Join-Path $PSScriptRoot "..\build\web\chromium-smoke.stderr.log"
try {
	Start-Sleep -Seconds 2
	& $chromePath `
		--headless `
		--no-sandbox `
		--disable-gpu `
		--hide-scrollbars `
		--window-size=1280,720 `
		--virtual-time-budget=12000 `
		--enable-logging=stderr `
		--log-level=0 `
		"--screenshot=$screenshotPath" `
		"http://127.0.0.1:8936/index.html" 2> $stderrPath
	if (-not (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
		throw "Chromium smoke test did not create a screenshot."
	}
}
finally {
	& "$PSScriptRoot\stop_web_server.ps1" -ProcessId ([int]$serverId)
}
