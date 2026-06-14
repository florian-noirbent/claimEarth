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
$profilePath = Join-Path $PSScriptRoot "..\build\web\chromium-profile"
try {
	Remove-Item -LiteralPath $screenshotPath -Force -ErrorAction SilentlyContinue
	Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
	Remove-Item -LiteralPath $profilePath -Recurse -Force -ErrorAction SilentlyContinue
	Start-Sleep -Seconds 2
	& $chromePath `
		--headless `
		--no-sandbox `
		--use-angle=swiftshader `
		--enable-unsafe-swiftshader `
		--hide-scrollbars `
		"--user-data-dir=$profilePath" `
		--window-size=1280,720 `
		--virtual-time-budget=30000 `
		--enable-logging=stderr `
		--log-level=0 `
		"--screenshot=$screenshotPath" `
		"http://127.0.0.1:8936/index.html" 2> $stderrPath
	$deadline = [DateTime]::UtcNow.AddSeconds(5)
	while (-not (Test-Path -LiteralPath $screenshotPath -PathType Leaf) -and [DateTime]::UtcNow -lt $deadline) {
		Start-Sleep -Milliseconds 100
	}
	if (-not (Test-Path -LiteralPath $screenshotPath -PathType Leaf)) {
		throw "Chromium smoke test did not create a screenshot."
	}
	$screenshotInfo = Get-Item -LiteralPath $screenshotPath
	if ($screenshotInfo.Length -lt 4096) {
		throw "Chromium smoke test produced an unexpectedly small screenshot."
	}
	$stderrText = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
		Get-Content -LiteralPath $stderrPath -Raw
	} else {
		""
	}
	if ($stderrText -match "(?im)\b(SEVERE|Uncaught|ReferenceError|TypeError|SCRIPT ERROR|ERROR:)\b") {
		throw "Chromium smoke test detected browser/runtime errors. See build/web/chromium-smoke.stderr.log."
	}
}
finally {
	& "$PSScriptRoot\stop_web_server.ps1" -ProcessId ([int]$serverId)
}
