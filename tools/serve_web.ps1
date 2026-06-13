$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\build\web")
$port = 8936
$python = (Get-Command python -ErrorAction Stop).Source
$stdoutPath = Join-Path $root "server.stdout.log"
$stderrPath = Join-Path $root "server.stderr.log"
$args = @("-m", "http.server", $port, "--bind", "127.0.0.1", "--directory", $root)
$process = Start-Process -FilePath $python -ArgumentList $args -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
Write-Output $process.Id
