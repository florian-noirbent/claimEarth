$ErrorActionPreference = "Stop"
. "$PSScriptRoot/platform.ps1"

$candidates = @($env:GODOT4)
if ($script:OnWindows) {
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA "Programs\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe"
    }
    $candidates += "C:\Program Files\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
} elseif ($script:OnMacOS) {
    $candidates += @(
        "/Applications/Godot.app/Contents/MacOS/Godot",
        (Join-Path $HOME "Applications/Godot.app/Contents/MacOS/Godot")
    )
}

$godot = Get-FirstExistingFile $candidates
if ($null -eq $godot) {
    $godot = Get-ApplicationOnPath @("godot", "godot4")
}
if ($null -eq $godot) {
    throw "Godot 4.7.2 was not found. Set the GODOT4 environment variable to the Godot executable or put godot on PATH."
}
return $godot
