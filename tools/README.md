# Development Commands

Automation resolves Godot in this order:

1. The `GODOT4` environment variable.
2. The standard GDScript editor installed at:

```text
%LOCALAPPDATA%\Programs\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe
```

3. The Mono console editor installed at
`C:\Program Files\Godot_v4.6.3-stable_mono_win64`, but it reports a missing .NET SDK
on the original workstation. Prefer the standard editor or set `GODOT4` explicitly.

From the repository root:

```powershell
.\tools\import.ps1
.\tools\test.ps1
.\tools\test_performance.ps1
.\tools\test_simulation_rendering.ps1
.\tools\validate_generation_plugin.ps1
.\tools\benchmark_terrain.ps1
.\tools\benchmark_world_presenter.ps1 -SaveBaseline
.\tools\benchmark_world_presenter.ps1 -Compare
.\tools\run_smoke.ps1
.\tools\export_web.ps1
.\tools\smoke_exported_game.ps1
.\tools\serve_web.ps1
.\tools\smoke_web.ps1
.\tools\smoke_chromium.ps1
.\tools\run_web_debug.ps1
.\tools\stop_web_debug.ps1
.\tools\run_phone_web.ps1
.\tools\stop_phone_web.ps1
.\tools\ci.ps1
.\tools\assert_test_failure.ps1
```

- `import.ps1` imports resources and verifies the project can open headlessly.
- `test.ps1` runs the fast contract, unit, and integration suites.
- `test_performance.ps1` runs deterministic performance contract tests.
- `test_simulation_rendering.ps1` uses a real Compatibility renderer to verify
  the fixed 60-pass clock, exact equivalence between sequential and six-pass batch
  rendering, alternating-bank texture safety, and stale-callback cancellation.
- `validate_generation_plugin.ps1` launches the editor with the `World Gen` main screen selected, waits for startup stability, and fails on a native editor crash.
- `benchmark_terrain.ps1` reports current terrain simulation, chunk drawing, and
  collision-build timing distributions for sparse, dense, and settled fixtures.
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
- `ci.ps1` runs the fast local gate by default. Use `.\tools\ci.ps1 -Milestone` to add performance tests plus web/browser smoke gates.
- `assert_test_failure.ps1` injects a temporary failing test and verifies the headless
  runner returns a nonzero exit code.

The `build/` directory is generated and ignored by Git. Its tracked `.gdignore`
file also prevents Godot from importing exports, browser profiles, and logs back
into the project.

Opening `build/web/index.html` directly with a `file://` URL is not a valid Web test.
Godot's `.pck` and WebAssembly payloads must be served over HTTP; use
`serve_web.ps1` or `run_web_debug.ps1`.
