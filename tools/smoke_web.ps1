$ErrorActionPreference = "Stop"

& "$PSScriptRoot\export_web.ps1"
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
}
finally {
	& "$PSScriptRoot\stop_web_server.ps1" -ProcessId ([int]$serverId)
}
