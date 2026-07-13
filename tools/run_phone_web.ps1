param(
	[int]$Port = 8936,
	[string]$Address = "",
	[switch]$Debug,
	[switch]$SkipExport
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildRoot = Join-Path $projectRoot "build"
$webRoot = Join-Path $buildRoot "web"
$logRoot = Join-Path $buildRoot "logs"
$certificateRoot = Join-Path $buildRoot "local-https"
$sessionPath = Join-Path $logRoot "phone-web-session.json"


function Resolve-LanAddress() {
	$defaultRoutes = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
		Where-Object { $_.NextHop -ne "0.0.0.0" } |
		Sort-Object RouteMetric, InterfaceMetric
	foreach ($route in $defaultRoutes) {
		$address = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue |
			Where-Object { $_.IPAddress -notmatch "^(127\.|169\.254\.)" } |
			Select-Object -First 1 -ExpandProperty IPAddress
		if (-not [string]::IsNullOrWhiteSpace($address)) {
			return $address
		}
	}
	throw "Could not determine a LAN IPv4 address. Pass -Address explicitly."
}


function Write-AsciiQr([string]$Url, [string]$PythonPath) {
	$packageRoot = Join-Path $buildRoot "tools\python-qrcode"
	$modulePath = Join-Path $packageRoot "qrcode\__init__.py"
	if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
		Write-Host "Installing the pinned ASCII QR helper into build/tools/python-qrcode..."
		New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
		& $PythonPath -m pip install `
			--disable-pip-version-check `
			--no-warn-script-location `
			--target $packageRoot `
			"qrcode==8.2"
		if ($LASTEXITCODE -ne 0) {
			throw "Could not install the qrcode helper package."
		}
	}

	$previousPythonPath = $env:PYTHONPATH
	$previousPythonIoEncoding = $env:PYTHONIOENCODING
	$previousOutputEncoding = [Console]::OutputEncoding
	try {
		$env:PYTHONPATH = $packageRoot
		$env:PYTHONIOENCODING = "utf-8"
		[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
		& $PythonPath -c "import qrcode,sys; qr=qrcode.QRCode(border=2); qr.add_data(sys.argv[1]); qr.make(fit=True); qr.print_ascii(tty=False)" $Url
		if ($LASTEXITCODE -ne 0) {
			throw "Could not render the phone-test QR code."
		}
	}
	finally {
		$env:PYTHONPATH = $previousPythonPath
		$env:PYTHONIOENCODING = $previousPythonIoEncoding
		[Console]::OutputEncoding = $previousOutputEncoding
	}
}


if ([string]::IsNullOrWhiteSpace($Address)) {
	$Address = Resolve-LanAddress
}

& "$PSScriptRoot\stop_phone_web.ps1" -Quiet

if (-not $SkipExport) {
	if ($Debug) {
		& "$PSScriptRoot\export_web.ps1" -Debug
	} else {
		& "$PSScriptRoot\export_web.ps1"
	}
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}

$indexPath = Join-Path $webRoot "index.html"
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
	throw "Phone Web test requires build/web/index.html. Run without -SkipExport first."
}

$certificatePath = Join-Path $certificateRoot "$Address.pem"
$keyPath = Join-Path $certificateRoot "$Address-key.pem"
if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf) -or
	-not (Test-Path -LiteralPath $keyPath -PathType Leaf)) {
	throw @"
No trusted HTTPS certificate was found for $Address.
Expected:
  $certificatePath
  $keyPath
Create it with mkcert, then install mkcert's root CA on the phone. See docs/WEB_PHONE_TESTING.md.
"@
}

$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($null -ne $listener) {
	throw "Port $Port is already used by PID $($listener.OwningProcess). Stop that process before starting the phone Web server."
}

$python = (Get-Command python -ErrorAction Stop).Source
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stdoutPath = Join-Path $logRoot "phone-server.stdout.log"
$stderrPath = Join-Path $logRoot "phone-server.stderr.log"
Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

$buildId = Get-Date -Format "yyyyMMdd-HHmmss"
$buildPrefix = "/build-$buildId"
$serverCode = @"
import http.server
import os
import ssl
import urllib.parse

os.chdir(r'$webRoot')
build_prefix = '$buildPrefix'

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        parsed = urllib.parse.urlsplit(path)
        request_path = parsed.path
        if request_path == build_prefix:
            request_path += '/'
        if request_path.startswith(build_prefix + '/'):
            request_path = request_path[len(build_prefix):]
        rewritten = urllib.parse.urlunsplit(('', '', request_path, parsed.query, ''))
        return super().translate_path(rewritten)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

server = http.server.ThreadingHTTPServer(('0.0.0.0', $Port), NoCacheHandler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(r'$certificatePath', r'$keyPath')
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
"@
$encodedServer = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($serverCode))
$serverArguments = "-c `"import base64;exec(base64.b64decode('$encodedServer'))`""
$serverProcess = Start-Process `
	-FilePath $python `
	-ArgumentList $serverArguments `
	-PassThru `
	-WindowStyle Hidden `
	-RedirectStandardOutput $stdoutPath `
	-RedirectStandardError $stderrPath

$deadline = [DateTime]::UtcNow.AddSeconds(5)
do {
	Start-Sleep -Milliseconds 100
	$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
} while ($null -eq $listener -and -not $serverProcess.HasExited -and [DateTime]::UtcNow -lt $deadline)

if ($serverProcess.HasExited -or $null -eq $listener) {
	throw "Phone Web server failed to start. See $stderrPath."
}

$url = "https://${Address}:$Port$buildPrefix/"
@{
	server_pid = $serverProcess.Id
	url = $url
	started_at = (Get-Date).ToString("o")
	stdout_log = $stdoutPath
	stderr_log = $stderrPath
} | ConvertTo-Json | Set-Content -LiteralPath $sessionPath

$response = Invoke-WebRequest -Uri $url -UseBasicParsing
if ($response.StatusCode -ne 200) {
	throw "Phone Web server returned HTTP $($response.StatusCode)."
}

Write-Host ""
Write-Host "Claim Earth phone Web build is ready:"
Write-Host $url -ForegroundColor Cyan
Write-Host ""
Write-AsciiQr $url $python
Write-Host "Server PID: $($serverProcess.Id)"
Write-Host "Request log: $stderrPath"
Write-Host "Stop server: .\tools\stop_phone_web.ps1"
