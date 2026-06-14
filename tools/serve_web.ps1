param(
	[int]$Port = 8936
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\build\web")
$python = (Get-Command python -ErrorAction Stop).Source
$logRoot = Join-Path $PSScriptRoot "..\build\logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stdoutPath = Join-Path $logRoot "server.stdout.log"
$stderrPath = Join-Path $logRoot "server.stderr.log"
$args = @("-m", "http.server", $Port, "--bind", "127.0.0.1", "--directory", $root)
$process = Start-Process -FilePath $python -ArgumentList $args -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
Write-Output $process.Id
