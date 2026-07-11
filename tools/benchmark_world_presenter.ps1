param(
	[switch]$SaveBaseline,
	[switch]$Compare,
	[switch]$Force,
	[ValidateRange(1, 20)]
	[int]$Runs = 5,
	[switch]$SkipChromium,
	[string]$ProjectRoot = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Stop"

if ($SaveBaseline -and $Compare) {
	throw "Use either -SaveBaseline or -Compare, not both."
}

$harnessProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$projectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$benchmarkScript = Join-Path $PSScriptRoot "benchmark_world_presenter.gd"
$usesExternalProjectRoot = -not [string]::Equals($projectRoot, $harnessProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)
# Keep references beside the active tooling checkout so a detached source tree can
# supply an old renderer while `-Compare` still finds its baseline in this checkout.
$benchmarkRoot = Join-Path $harnessProjectRoot "build\benchmarks\world_presenter"
$baselineRoot = Join-Path $benchmarkRoot "baseline"
$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchmarkRoot ("run-" + $runId)
$godot = & "$PSScriptRoot\resolve_godot.ps1"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

if ($usesExternalProjectRoot) {
	# A detached worktree has no `.godot` class cache yet. Populate it before
	# loading this checkout's benchmark script against the reference project.
	& $godot --headless --editor --path $projectRoot --quit | ForEach-Object { Write-Host $_ }
	if ($LASTEXITCODE -ne 0) { throw "Could not import benchmark project root: $projectRoot" }
}

function Get-Stats([double[]]$Values) {
	$sorted = @($Values | Sort-Object)
	$index95 = [Math]::Min($sorted.Count - 1, [Math]::Ceiling($sorted.Count * 0.95) - 1)
	return [ordered]@{
		min_usec = $sorted[0]
		median_usec = $sorted[[int]($sorted.Count / 2)]
		p95_usec = $sorted[$index95]
		max_usec = $sorted[$sorted.Count - 1]
		mean_usec = ($sorted | Measure-Object -Average).Average
	}
}

function Invoke-NativeBenchmark {
	$nativeRuns = @()
	for ($run = 1; $run -le $Runs; $run++) {
		$output = Join-Path $runRoot ("native-run-{0:D2}.json" -f $run)
		$screenshotArgument = @()
		if ($run -eq 1) {
			$screenshots = Join-Path $runRoot "screenshots\native"
			New-Item -ItemType Directory -Force -Path $screenshots | Out-Null
			$screenshotArgument = @("--screenshots", $screenshots)
		}
		Write-Host "Native presenter benchmark $run/$Runs"
		& $godot --path $projectRoot --rendering-driver opengl3 --resolution 1280x720 --disable-vsync --script $benchmarkScript -- --output $output @screenshotArgument | ForEach-Object { Write-Host $_ }
		if ($LASTEXITCODE -ne 0) { throw "Native presenter benchmark run $run failed." }
		$nativeRuns += Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
	}
	$scenarios = [ordered]@{}
	foreach ($name in @($nativeRuns[0].scenarios.psobject.Properties | ForEach-Object Name)) {
		$scenario = [ordered]@{}
		foreach ($metric in @("min_usec", "median_usec", "p95_usec", "p99_usec", "max_usec", "mean_usec")) {
			$values = [double[]]@($nativeRuns | ForEach-Object { $_.scenarios.$name.$metric })
			$scenario[$metric] = Get-Stats $values
		}
		$scenarios[$name] = $scenario
	}
	return [ordered]@{
		environment = $nativeRuns[0].environment
		runs = $Runs
		scenarios = $scenarios
	}
}

function Invoke-ChromiumReference {
	if ($SkipChromium) { return [ordered]@{ status = "skipped" } }
	if ($usesExternalProjectRoot) {
		return [ordered]@{ status = "skipped"; reason = "Web export uses the active tools checkout; pass -SkipChromium when benchmarking a detached project root." }
	}
	& "$PSScriptRoot\export_web.ps1" | ForEach-Object { Write-Host $_ }
	if ($LASTEXITCODE -ne 0) { throw "Web export failed." }
	$chromePath = @(
		"C:\Program Files\Google\Chrome\Application\chrome.exe",
		"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
	) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
	if ([string]::IsNullOrWhiteSpace($chromePath)) { return [ordered]@{ status = "unavailable"; reason = "Chrome was not found." } }
	$serverId = & "$PSScriptRoot\serve_web.ps1" -Port 8937
	$screenshot = Join-Path $runRoot "screenshots\chromium-main-menu.png"
	$profile = Join-Path $runRoot "chromium-profile"
	New-Item -ItemType Directory -Force -Path (Split-Path $screenshot) | Out-Null
	try {
		Start-Sleep -Seconds 2
		& $chromePath --headless --no-sandbox --hide-scrollbars "--user-data-dir=$profile" --window-size=1280,720 --virtual-time-budget=10000 "--screenshot=$screenshot" "http://127.0.0.1:8937/index.html" | ForEach-Object { Write-Host $_ }
		if (-not (Test-Path -LiteralPath $screenshot -PathType Leaf)) { throw "Chromium did not create its reference screenshot." }
		return [ordered]@{ status = "captured"; screenshot = "screenshots/chromium-main-menu.png"; chrome = (& $chromePath --version) }
	} finally {
		& "$PSScriptRoot\stop_web_server.ps1" -ProcessId ([int]$serverId)
	}
}

$gitCommit = "unknown"
$gitDirty = $false
try {
	$gitCommit = ((& git -C $projectRoot rev-parse HEAD 2>$null) | Select-Object -First 1).Trim()
	$gitDirty = -not [string]::IsNullOrWhiteSpace((& git -C $projectRoot status --porcelain 2>$null))
} catch {
	# The benchmark remains useful outside a Git checkout.
}

$report = [ordered]@{
	schema_version = 1
	created_utc = [DateTime]::UtcNow.ToString("o")
	project_root = $projectRoot
	git_commit = $gitCommit
	git_dirty = $gitDirty
	native = Invoke-NativeBenchmark
	chromium = Invoke-ChromiumReference
}

$reportPath = Join-Path $runRoot "report.json"
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding utf8

if ($SaveBaseline) {
	if ((Test-Path -LiteralPath $baselineRoot) -and -not $Force) { throw "A baseline already exists at $baselineRoot. Use -Force to replace it." }
	if (Test-Path -LiteralPath $baselineRoot) { Remove-Item -LiteralPath $baselineRoot -Recurse -Force }
	Copy-Item -LiteralPath $runRoot -Destination $baselineRoot -Recurse
	Write-Host "Saved world presenter baseline: $baselineRoot"
} elseif ($Compare) {
	$baselinePath = Join-Path $baselineRoot "report.json"
	if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) { throw "No baseline found. Run with -SaveBaseline first." }
	$baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
	$comparisonData = [ordered]@{}
	foreach ($scenario in @($report.native.scenarios.Keys)) {
		$comparisonData[$scenario] = [ordered]@{}
		$baselineScenario = $baseline.native.scenarios.psobject.Properties | Where-Object Name -eq $scenario | Select-Object -First 1
		$currentScenario = $report.native.scenarios[$scenario]
		foreach ($metric in @("median_usec", "p95_usec")) {
			$baselineMetric = $baselineScenario.Value.psobject.Properties | Where-Object Name -eq $metric | Select-Object -First 1
			$currentMetric = $currentScenario[$metric]
			$before = [double]$baselineMetric.Value.median_usec
			$after = [double]$currentMetric.median_usec
			$comparisonData[$scenario][$metric] = [ordered]@{ baseline_usec = $before; current_usec = $after; change_percent = if ($before -eq 0) { 0 } else { (($after - $before) / $before) * 100 } }
		}
	}
	$comparisonPath = Join-Path $runRoot "comparison.json"
	ConvertTo-Json -InputObject ([PSCustomObject]$comparisonData) -Depth 8 | Set-Content -LiteralPath $comparisonPath -Encoding utf8
	Write-Host "Comparison: $comparisonPath"
}

Write-Host "World presenter benchmark report: $reportPath"
