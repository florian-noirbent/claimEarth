# Development Commands

The project uses the standard GDScript editor installed at:

```text
%LOCALAPPDATA%\Programs\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe
```

The user-level `GODOT4` environment variable should point to that executable. Tool
scripts prefer `GODOT4` and use the path above as a local fallback. The original
Mono editor remains installed at
`C:\Program Files\Godot_v4.6.3-stable_mono_win64`, but it reports a missing .NET SDK
while importing even a GDScript-only project, so automation deliberately uses the
standard editor.

From the repository root:

```powershell
.\tools\import.ps1
.\tools\test.ps1
.\tools\run_smoke.ps1
.\tools\export_web.ps1
```

- `import.ps1` imports resources and verifies the project can open headlessly.
- `test.ps1` runs all GUT tests under `res://tests` and propagates the exit code.
- `run_smoke.ps1` starts the configured main scene for two frames.
- `export_web.ps1` creates a release build under `build/web`.

The `build/` directory is generated and ignored by Git.
