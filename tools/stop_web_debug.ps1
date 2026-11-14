param(
	[switch]$Quiet
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/platform.ps1"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildRoot = Join-Path $projectRoot "build"
$logRoot = Join-Path $buildRoot "logs"
$profileRoot = (Join-Path $buildRoot "chrome-web-debug-profile").ToString()
$sessionPath = Join-Path $logRoot "web-debug-session.json"

if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
	$session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
	if ($null -ne $session.server_pid) {
		$serverProcess = Get-Process -Id ([int]$session.server_pid) -ErrorAction SilentlyContinue
		if ($null -ne $serverProcess) {
			Stop-Process -Id $serverProcess.Id -Force
		}
	}
}

# Only Chrome processes that use this session's private profile are stopped.
foreach ($processId in (Get-ProcessIdsByCommandLine "--user-data-dir=$profileRoot")) {
	Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $sessionPath) {
	Remove-Item -LiteralPath $sessionPath -Force
}
if (-not $Quiet) {
	Write-Host "Claim Earth web diagnostic session stopped."
}
