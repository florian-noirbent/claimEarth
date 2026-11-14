$ErrorActionPreference = "Stop"
. "$PSScriptRoot/platform.ps1"

& "$PSScriptRoot/export_web.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

$chromePath = Get-ChromePath
if ($null -eq $chromePath) {
	throw "Chrome was not found for the Chromium smoke test. Install Google Chrome, or set CHROME_PATH to its executable."
}

$serverId = & "$PSScriptRoot/serve_web.ps1"
$screenshotPath = Join-Path $PSScriptRoot "../build/web/chromium-smoke.png"
$stderrPath = Join-Path $PSScriptRoot "../build/web/chromium-smoke.stderr.log"
$profilePath = Join-Path $PSScriptRoot "../build/web/chromium-profile"
try {
	Remove-Item -LiteralPath $screenshotPath -Force -ErrorAction SilentlyContinue
	Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
	Remove-Item -LiteralPath $profilePath -Recurse -Force -ErrorAction SilentlyContinue
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
	$stderrLines = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
		@(Get-Content -LiteralPath $stderrPath)
	} else {
		@()
	}
	# Chrome's own diagnostics that say nothing about the game: macOS headless display
	# links, GPU performance notes, and Chrome's bundled web-app installs.
	$benignChromePattern = "cv_display_link_mac|GL Driver Message \([^)]*, Performance,|externally_managed_app_manager"
	$errorLines = @($stderrLines | Where-Object {
		$_ -match "(?i)\b(SEVERE|Uncaught|ReferenceError|TypeError|SCRIPT ERROR|ERROR:)\b" -and
		$_ -notmatch $benignChromePattern
	})
	if ($errorLines.Count -gt 0) {
		$errorLines | Select-Object -First 5 | ForEach-Object { Write-Host $_ }
		throw "Chromium smoke test detected browser/runtime errors. See build/web/chromium-smoke.stderr.log."
	}
}
finally {
	& "$PSScriptRoot/stop_web_server.ps1" -ProcessId ([int]$serverId)
}
