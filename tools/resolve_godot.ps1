$ErrorActionPreference = "Stop"

$candidates = @(
    $env:GODOT4,
    (Join-Path $env:LOCALAPPDATA "Programs\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe"),
    "C:\Program Files\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
) | Where-Object { $_ }

foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }
}

throw "Godot 4.6.3 was not found. Set the GODOT4 environment variable to the console executable."
