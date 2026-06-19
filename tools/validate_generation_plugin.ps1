param(
    [int]$StartupTimeoutSeconds = 12,
    [int]$PluginMainScreenIndex = 5
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godot = & (Join-Path $PSScriptRoot "resolve_godot.ps1")
$layoutDir = Join-Path $projectRoot ".godot\editor"
$layoutPath = Join-Path $layoutDir "editor_layout.cfg"
$backupPath = Join-Path $layoutDir "editor_layout.cfg.codex_backup"
$startupTime = Get-Date
$process = $null

function Set-PluginLayout {
    param(
        [string]$Path,
        [int]$MainScreenIndex
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match "selected_main_editor_idx=\d+") {
        $content = [regex]::Replace($content, "selected_main_editor_idx=\d+", "selected_main_editor_idx=$MainScreenIndex", 1)
    } else {
        $content += "`r`n[EditorNode]`r`nselected_main_editor_idx=$MainScreenIndex`r`n"
    }
    Set-Content -LiteralPath $Path -Value $content -NoNewline
}

try {
    New-Item -ItemType Directory -Force -Path $layoutDir | Out-Null
    if (Test-Path -LiteralPath $layoutPath) {
        Copy-Item -LiteralPath $layoutPath -Destination $backupPath -Force
    }
    Set-PluginLayout -Path $layoutPath -MainScreenIndex $PluginMainScreenIndex

    $args = @("--editor", "--path", $projectRoot)
    $process = Start-Process -FilePath $godot -ArgumentList $args -PassThru -WindowStyle Hidden

    if (-not $process.WaitForExit($StartupTimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
        Write-Host "Generation plugin validation passed: editor stayed alive for $StartupTimeoutSeconds seconds."
        exit 0
    }

    $recentCrash = Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$startupTime.AddSeconds(-2)} |
        Where-Object {
            $_.ProviderName -eq 'Application Error' -and
            $_.Message -like '*Godot_v4.6.3-stable_win64.exe*'
        } |
        Select-Object -First 1

    if ($recentCrash -ne $null) {
        throw "Godot crashed during plugin validation. Crash time: $($recentCrash.TimeCreated)."
    }

    if ($process.ExitCode -ne 0) {
        throw "Godot exited before the timeout with code $($process.ExitCode)."
    }

    throw "Godot exited before the timeout without a recorded Application Error. Treating this as a plugin validation failure."
}
finally {
    if ($process -ne $null -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
    }

    if (Test-Path -LiteralPath $backupPath) {
        Move-Item -LiteralPath $backupPath -Destination $layoutPath -Force
    }
}
