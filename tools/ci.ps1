param(
	[switch]$Milestone
)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\import.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& "$PSScriptRoot\test.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& "$PSScriptRoot\run_smoke.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

if (-not $Milestone) {
	exit 0
}

& "$PSScriptRoot\test_performance.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& "$PSScriptRoot\smoke_web.ps1"
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& "$PSScriptRoot\smoke_chromium.ps1"
exit $LASTEXITCODE
