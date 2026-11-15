# Development Commands

The scripts run on Windows and macOS. On Windows, use Windows PowerShell 5.1 or
PowerShell 7. On macOS, use PowerShell 7 (`pwsh`). `platform.ps1` holds the shared
helpers that find tools and start background processes on each system.

## Prerequisites

| Tool | Windows | macOS (Homebrew) |
| --- | --- | --- |
| Godot 4.7.2 and its export templates | Godot website | `brew install --cask godot` |
| PowerShell 7 | built in (5.1) or `winget install Microsoft.PowerShell` | `brew install powershell` |
| Git LFS (art, fonts, audio) | `winget install GitHub.GitLFS` | `brew install git-lfs` |
| Python 3 (local Web servers) | python.org or `winget install Python.Python.3` | `brew install python` |
| Google Chrome (browser smoke and debug) | google.com/chrome | google.com/chrome |
| mkcert (phone HTTPS only) | `winget install FiloSottile.mkcert` | `brew install mkcert` |

After cloning, run `git lfs install` and `git lfs pull` once. Without them the
assets are LFS pointer files and the game cannot import them.

## How the scripts find tools

- Godot: the `GODOT4` environment variable, then the standard install locations
  (`%LOCALAPPDATA%\Programs\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`
  or the Mono build under `C:\Program Files` on Windows, `/Applications/Godot.app`
  on macOS), then `godot` or `godot4` on `PATH`. The Mono editor reports a missing
  .NET SDK on the original workstation, so prefer the standard editor.
- Python: the `PYTHON` environment variable, then `python`, `py`, or `python3` on
  Windows and `python3` or `python` on macOS. A candidate counts only if it runs as
  Python 3, which skips the Windows Store stub and unconfigured version-manager shims.
- Chrome: the `CHROME_PATH` environment variable, then the standard Chrome install
  locations, then Chromium.

## Commands

From the repository root (prefix with `pwsh` on macOS, for example
`pwsh ./tools/test.ps1`):

```powershell
./tools/import.ps1
./tools/test.ps1
./tools/test_performance.ps1
./tools/test_simulation_rendering.ps1
./tools/validate_generation_plugin.ps1
./tools/benchmark_terrain.ps1
./tools/benchmark_world_presenter.ps1 -SaveBaseline
./tools/benchmark_world_presenter.ps1 -Compare
./tools/run_smoke.ps1
./tools/export_web.ps1
./tools/smoke_exported_game.ps1
./tools/serve_web.ps1
./tools/smoke_web.ps1
./tools/smoke_chromium.ps1
./tools/run_web_debug.ps1
./tools/stop_web_debug.ps1
./tools/run_phone_web.ps1
./tools/stop_phone_web.ps1
./tools/ci.ps1
./tools/assert_test_failure.ps1
```

- `import.ps1` imports resources and verifies the project can open headlessly.
- `test.ps1` runs the fast contract, unit, and integration suites.
- `test_performance.ps1` runs deterministic performance contract tests.
- `test_simulation_rendering.ps1` uses a real Compatibility renderer to verify
  the fixed 60-pass clock, exact equivalence between sequential and six-pass batch
  rendering, alternating-bank texture safety, and stale-callback cancellation.
- `validate_generation_plugin.ps1` launches the editor with the `World Gen` main screen selected, waits for startup stability, and fails on a native editor crash.
- `benchmark_terrain.ps1` runs the GPU terrain simulation with a real renderer and
  reports initial and steady tick timing distributions for settled, fluid, sand,
  mixed, dense, and generated-world fixtures.
- `benchmark_world_presenter.ps1` renders deterministic presenter fixtures at
  1280×720 with VSync disabled, saves a five-run native reference under
  `build/benchmarks/world_presenter/baseline`, and compares subsequent five-run
  measurements. It also saves a Chromium Web-export screenshot as an export
  reference; it is not a browser GPU-timing measurement. Use `-Force` only to
  replace the saved baseline and `-SkipChromium` when Web export is unavailable.
  `-ProjectRoot <path>` lets a detached checkout supply the game assets for a
  native pre-change baseline while retaining this harness script.
- `run_smoke.ps1` starts the configured main scene for two frames.
- `export_web.ps1` creates a release build under `build/web` using Godot's
  canonical all-project-resources export mode.
- `smoke_exported_game.ps1` runs the exported PCK headlessly, presses the real
  main-menu Start button, and verifies the game reaches `PLAYING`.
- `serve_web.ps1` starts a local static server for the exported build on `127.0.0.1:8936`.
- `smoke_web.ps1` exports the build, verifies required web artifacts exist, serves it locally, and checks the shell plus payloads load.
- `smoke_chromium.ps1` exports the build, serves it locally, captures a Chrome headless screenshot, and fails on severe browser/runtime console errors.
- `run_web_debug.ps1` creates a debug Web export, serves it locally, and opens an isolated Chrome session with DevTools plus persistent browser/server logs under `build/logs`.
- `stop_web_debug.ps1` stops the isolated Chrome session and local Web server.
- `run_phone_web.ps1` rebuilds and serves the Web game over trusted LAN HTTPS,
  disables browser caching, and prints the phone URL as an ASCII QR code.
- `stop_phone_web.ps1` stops the managed phone HTTPS server.
- `ci.ps1` runs the fast local gate by default. Use `./tools/ci.ps1 -Milestone` to add performance tests plus web/browser smoke gates.
- `assert_test_failure.ps1` injects a temporary failing test and verifies the headless
  runner returns a nonzero exit code.
- Player art pipeline (Python scripts need Pillow, NumPy, and SciPy):
  - `slice_player_reference.py` cuts `assets/objects/player/source/reference.png`
    into the redraw template under `source/template` and `source/parts_sheet.png`.
  - `extract_player_parts.py` extracts the part textures the game uses from the
	repainted sheet `source/parts_redraw.png`, which must keep the template sheet's
	cell layout.
  - `build_player_rig.gd` generates `scenes/player/player_rig.tscn` from its bone
	and animation tables: run `./tools/import.ps1`, then
	`godot --headless --path . --script res://tools/build_player_rig.gd`. The
	tables are the source of the rig, so scene edits made in the editor are lost
	on the next run.

The `build/` directory is generated and ignored by Git. Its tracked `.gdignore`
file also prevents Godot from importing exports, browser profiles, and logs back
into the project.

Opening `build/web/index.html` directly with a `file://` URL is not a valid Web test.
Godot's `.pck` and WebAssembly payloads must be served over HTTP; use
`serve_web.ps1` or `run_web_debug.ps1`.
