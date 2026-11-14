param(
	[int]$Port = 8936,
	[switch]$SkipExport
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/platform.ps1"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildRoot = Join-Path $projectRoot "build"
$logRoot = Join-Path $buildRoot "logs"
$profileRoot = Join-Path $buildRoot "chrome-web-debug-profile"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

& "$PSScriptRoot/stop_web_debug.ps1" -Quiet

if (-not $SkipExport) {
	& "$PSScriptRoot/export_web.ps1" -Debug
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

$chromePath = Get-ChromePath
if ($null -eq $chromePath) {
	throw "Chrome was not found. Install Google Chrome, or set CHROME_PATH to its executable."
}

$serverId = & "$PSScriptRoot/serve_web.ps1" -Port $Port
$buildId = Get-Date -Format "yyyyMMdd-HHmmss"
$browserStdout = Join-Path $logRoot "chrome.stdout.log"
$browserStderr = Join-Path $logRoot "chrome.stderr.log"
$url = "http://127.0.0.1:$Port/index.html?diagnostic=$buildId"
$chromeArgs = @(
	"--user-data-dir=$profileRoot",
	"--no-first-run",
	"--no-default-browser-check",
	"--disable-extensions",
	"--new-window",
	"--auto-open-devtools-for-tabs",
	"--enable-logging=stderr",
	"--log-level=0",
	"--disable-cache",
	"--disk-cache-size=1",
	"--remote-debugging-port=9222",
	$url
)
$browserProcess = Start-BackgroundProcess $chromePath $chromeArgs $browserStdout $browserStderr -Visible

@{
	server_pid = [int]$serverId
	browser_pid = $browserProcess.Id
	url = $url
	started_at = (Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logRoot "web-debug-session.json")

Write-Host "Claim Earth web diagnostic session is running."
Write-Host "URL: $url"
Write-Host "Chrome DevTools opens automatically. Reproduce the Start-button failure, then close Chrome."
Write-Host "Browser log: $browserStderr"
Write-Host "Server log:  $(Join-Path $logRoot 'server.stderr.log')"
Write-Host "Stop session: ./tools/stop_web_debug.ps1"
