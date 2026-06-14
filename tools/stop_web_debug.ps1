param(
	[switch]$Quiet
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$buildRoot = Join-Path $projectRoot "build"
$logRoot = Join-Path $buildRoot "logs"
$profileRoot = Join-Path $buildRoot "chrome-web-debug-profile"
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

$profileProcesses = Get-CimInstance Win32_Process | Where-Object {
	$_.Name -eq "chrome.exe" -and $_.CommandLine -like "*$profileRoot*"
}
foreach ($profileProcess in $profileProcesses) {
	Stop-Process -Id $profileProcess.ProcessId -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $sessionPath) {
	Remove-Item -LiteralPath $sessionPath -Force
}
if (-not $Quiet) {
	Write-Host "Claim Earth web diagnostic session stopped."
}
