# Shared helpers that keep the tools scripts working on Windows and macOS.
# Dot-source it: . "$PSScriptRoot/platform.ps1"
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.

$script:OnWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or $IsWindows
$script:OnMacOS = (-not $script:OnWindows) -and $IsMacOS


function Get-FirstExistingFile([string[]]$Candidates) {
	foreach ($candidate in $Candidates) {
		if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
			return (Resolve-Path -LiteralPath $candidate).Path
		}
	}
	return $null
}


function Get-ApplicationOnPath([string[]]$Names) {
	foreach ($name in $Names) {
		$command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($null -ne $command) {
			return $command.Source
		}
	}
	return $null
}


# Returns the Chrome or Chromium executable, or $null. CHROME_PATH overrides the search.
function Get-ChromePath() {
	$candidates = @($env:CHROME_PATH)
	if ($script:OnWindows) {
		$candidates += @(
			(Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
			"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
		)
		if ($env:LOCALAPPDATA) {
			$candidates += Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"
		}
	} elseif ($script:OnMacOS) {
		$candidates += @(
			"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
			(Join-Path $HOME "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
			"/Applications/Chromium.app/Contents/MacOS/Chromium"
		)
	}
	$found = Get-FirstExistingFile $candidates
	if ($null -ne $found) {
		return $found
	}
	return Get-ApplicationOnPath @("google-chrome", "google-chrome-stable", "chromium", "chromium-browser")
}


# Returns a working Python 3 interpreter. PYTHON overrides the search.
# Each candidate is run once, which skips the Windows Store stub and unconfigured shims.
function Get-PythonPath() {
	$candidates = @()
	if ($env:PYTHON) {
		$candidates += $env:PYTHON
	}
	$names = if ($script:OnWindows) { @("python", "py", "python3") } else { @("python3", "python") }
	foreach ($name in $names) {
		$command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($null -ne $command) {
			$candidates += $command.Source
		}
	}
	foreach ($candidate in $candidates) {
		$major = $null
		try {
			$major = & $candidate -c "import sys; print(sys.version_info[0])" 2>$null
		} catch {
			continue
		}
		if ($LASTEXITCODE -eq 0 -and "$major".Trim() -eq "3") {
			return $candidate
		}
	}
	throw "Python 3 was not found. Install it, or set the PYTHON environment variable to its executable."
}


function ConvertTo-WindowsArgument([string]$Argument) {
	if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
		return $Argument
	}
	return '"' + ($Argument -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
}


# Starts a process that keeps running after this script exits, with its output in
# files. Pass arguments unquoted. A console program's window is hidden on Windows;
# use -Visible for a GUI program such as Chrome.
function Start-BackgroundProcess(
	[string]$FilePath,
	[string[]]$ArgumentList,
	[string]$StdoutPath,
	[string]$StderrPath,
	[switch]$Visible
) {
	if ($script:OnWindows) {
		$options = @{
			FilePath = $FilePath
			ArgumentList = (($ArgumentList | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join " ")
			PassThru = $true
			RedirectStandardOutput = $StdoutPath
			RedirectStandardError = $StderrPath
		}
		if (-not $Visible) {
			$options.WindowStyle = "Hidden"
		}
		return Start-Process @options
	}
	# On Unix, Start-Process redirects through pipes owned by this PowerShell process,
	# and the child breaks when they close. A shell gives the child real file handles.
	$startInfo = New-Object System.Diagnostics.ProcessStartInfo
	$startInfo.FileName = "/bin/sh"
	$startInfo.UseShellExecute = $false
	$startInfo.ArgumentList.Add("-c")
	$startInfo.ArgumentList.Add('out="$1"; err="$2"; shift 2; exec "$@" <"/dev/null" >"$out" 2>"$err"')
	$startInfo.ArgumentList.Add("sh")
	$startInfo.ArgumentList.Add($StdoutPath)
	$startInfo.ArgumentList.Add($StderrPath)
	$startInfo.ArgumentList.Add($FilePath)
	foreach ($argument in $ArgumentList) {
		$startInfo.ArgumentList.Add([string]$argument)
	}
	return [System.Diagnostics.Process]::Start($startInfo)
}


# True when something accepts TCP connections on 127.0.0.1:$Port.
function Test-LocalPortListening([int]$Port) {
	$client = New-Object System.Net.Sockets.TcpClient
	try {
		$connection = $client.BeginConnect("127.0.0.1", $Port, $null, $null)
		if (-not $connection.AsyncWaitHandle.WaitOne(250)) {
			return $false
		}
		$client.EndConnect($connection)
		return $true
	} catch {
		return $false
	} finally {
		$client.Close()
	}
}


# The IPv4 address of the interface that holds the default route.
# Connecting a UDP socket only selects a route; it sends no packet.
function Get-LanIPv4Address() {
	$socket = New-Object System.Net.Sockets.Socket(
		[System.Net.Sockets.AddressFamily]::InterNetwork,
		[System.Net.Sockets.SocketType]::Dgram,
		[System.Net.Sockets.ProtocolType]::Udp
	)
	try {
		$socket.Connect("192.0.2.1", 9)
		$address = $socket.LocalEndPoint.Address.ToString()
	} catch {
		$address = $null
	} finally {
		$socket.Dispose()
	}
	if ([string]::IsNullOrWhiteSpace($address) -or $address -match "^(0\.|127\.|169\.254\.)") {
		throw "Could not determine a LAN IPv4 address. Pass -Address explicitly."
	}
	return $address
}


# Process IDs whose command line contains $Text.
function Get-ProcessIdsByCommandLine([string]$Text) {
	if ($script:OnWindows) {
		return @(Get-CimInstance Win32_Process |
			Where-Object { $null -ne $_.CommandLine -and $_.CommandLine.Contains($Text) } |
			ForEach-Object { [int]$_.ProcessId })
	}
	$ids = @()
	foreach ($line in (& ps -axo "pid=,command=")) {
		$trimmed = $line.Trim()
		$separator = $trimmed.IndexOf(" ")
		if ($separator -gt 0 -and $trimmed.Substring($separator + 1).Contains($Text)) {
			$ids += [int]$trimmed.Substring(0, $separator)
		}
	}
	return $ids
}
