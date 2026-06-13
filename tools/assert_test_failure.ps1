$ErrorActionPreference = "Stop"

$tempDir = Join-Path $PSScriptRoot "..\tests\_temp_failure"
$testPath = Join-Path $tempDir "test_intentional_failure.gd"

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$testSource = @'
extends GutTest


func test_intentional_failure() -> void:
	assert_true(false)
'@

Set-Content -LiteralPath $testPath -Value $testSource -NoNewline

try {
	& "$PSScriptRoot\test.ps1"
	$exitCode = $LASTEXITCODE
} finally {
	Remove-Item -LiteralPath $testPath -Force -ErrorAction SilentlyContinue
	if (Test-Path -LiteralPath $tempDir) {
		Remove-Item -LiteralPath $tempDir -Force -ErrorAction SilentlyContinue
	}
}

if ($exitCode -eq 0) {
	throw "Expected the temporary failing test to produce a nonzero exit code."
}

Write-Output "Observed expected nonzero test exit code: $exitCode"
