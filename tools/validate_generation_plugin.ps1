param(
    [int]$StartupTimeoutSeconds = 12,
    [int]$PluginMainScreenIndex = 5
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/platform.ps1"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godot = & (Join-Path $PSScriptRoot "resolve_godot.ps1")
$layoutDir = Join-Path $projectRoot ".godot/editor"
$layoutPath = Join-Path $layoutDir "editor_layout.cfg"
$backupPath = Join-Path $layoutDir "editor_layout.cfg.codex_backup"
$startupTime = Get-Date
$process = $null

# Returns a short description of a native Godot crash recorded since $Since, or $null.
function Find-GodotCrash([datetime]$Since) {
    if ($script:OnWindows) {
        $crash = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $Since } -ErrorAction SilentlyContinue |
            Where-Object { $_.ProviderName -eq 'Application Error' -and $_.Message -like '*Godot*' } |
            Select-Object -First 1
        if ($null -ne $crash) {
            return "Application Error at $($crash.TimeCreated)"
        }
    } elseif ($script:OnMacOS) {
        $reportDir = Join-Path $HOME "Library/Logs/DiagnosticReports"
        $crash = Get-ChildItem -LiteralPath $reportDir -Filter "Godot*" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $Since } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($null -ne $crash) {
            return "crash report $($crash.FullName)"
        }
    }
    return $null
}

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
        $content += "`n[EditorNode]`nselected_main_editor_idx=$MainScreenIndex`n"
    }
    Set-Content -LiteralPath $Path -Value $content -NoNewline
}

try {
    New-Item -ItemType Directory -Force -Path $layoutDir | Out-Null
    if (Test-Path -LiteralPath $layoutPath) {
        Copy-Item -LiteralPath $layoutPath -Destination $backupPath -Force
    }
    Set-PluginLayout -Path $layoutPath -MainScreenIndex $PluginMainScreenIndex

    $editorArgs = @("--editor", "--path", "`"$projectRoot`"")
    $startOptions = @{ FilePath = $godot; ArgumentList = $editorArgs; PassThru = $true }
    if ($script:OnWindows) {
        $startOptions.WindowStyle = "Hidden"
    }
    $process = Start-Process @startOptions

    if (-not $process.WaitForExit($StartupTimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
        Write-Host "Generation plugin validation passed: editor stayed alive for $StartupTimeoutSeconds seconds."
        exit 0
    }

    $recentCrash = Find-GodotCrash $startupTime.AddSeconds(-2)
    if ($null -ne $recentCrash) {
        throw "Godot crashed during plugin validation: $recentCrash."
    }

    if ($process.ExitCode -ne 0) {
        throw "Godot exited before the timeout with code $($process.ExitCode)."
    }

    throw "Godot exited before the timeout without a recorded crash. Treating this as a plugin validation failure."
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
