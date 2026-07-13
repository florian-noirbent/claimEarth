param(
	[switch]$Quiet
)

$ErrorActionPreference = "Stop"
$sessionPath = Join-Path $PSScriptRoot "..\build\logs\phone-web-session.json"
if (-not (Test-Path -LiteralPath $sessionPath -PathType Leaf)) {
	if (-not $Quiet) {
		Write-Host "No managed phone Web server is running."
	}
	exit 0
}

$session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
$process = Get-Process -Id ([int]$session.server_pid) -ErrorAction SilentlyContinue
if ($null -ne $process) {
	if ($process.ProcessName -notmatch "^python") {
		throw "Refusing to stop PID $($process.Id): expected a Python phone Web server, found $($process.ProcessName)."
	}
	Stop-Process -Id $process.Id -Force
	if (-not $Quiet) {
		Write-Host "Stopped phone Web server PID $($process.Id)."
	}
}

Remove-Item -LiteralPath $sessionPath -Force -ErrorAction SilentlyContinue
