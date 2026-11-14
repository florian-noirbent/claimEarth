param(
	[int]$Port = 8936
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/platform.ps1"

$root = (Resolve-Path (Join-Path $PSScriptRoot "../build/web")).Path
$python = Get-PythonPath
$logRoot = Join-Path $PSScriptRoot "../build/logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stdoutPath = Join-Path $logRoot "server.stdout.log"
$stderrPath = Join-Path $logRoot "server.stderr.log"
$serverArgs = @("-m", "http.server", "$Port", "--bind", "127.0.0.1", "--directory", $root)
$process = Start-BackgroundProcess $python $serverArgs $stdoutPath $stderrPath

$deadline = [DateTime]::UtcNow.AddSeconds(5)
while (-not (Test-LocalPortListening $Port) -and -not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
	Start-Sleep -Milliseconds 100
}
if ($process.HasExited -or -not (Test-LocalPortListening $Port)) {
	throw "Web server failed to start on port $Port. See $stderrPath."
}
Write-Output $process.Id
