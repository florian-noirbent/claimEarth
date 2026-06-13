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

& "$PSScriptRoot\export_web.ps1"
exit $LASTEXITCODE
