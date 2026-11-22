# Claim Earth

Claim Earth is a small Godot arcade game about descending through a generated hex cave with bombs, a grappling hook, and a flag used to bank the run's depth. The base game is implemented; current work is maintenance, portfolio polish, and feature development.

## Play

- [Play on itch.io](https://titan-koyos.itch.io/claim-earth)
- [Play on GitHub Pages](https://florian-noirbent.github.io/claimEarth)

GitHub Pages deploys the current Web build automatically whenever `main` is updated. GitHub README pages do not allow embedded game iframes, so both play buttons open the game on a full page.

## Quick Start

Use Godot 4.7.2 with the Compatibility renderer. The development scripts run on
Windows and macOS; [`tools/README.md`](tools/README.md) lists the prerequisites
for each. The art, fonts, and audio are stored in Git LFS, so run `git lfs install`
and `git lfs pull` once after cloning. From the repository root:

```powershell
./tools/import.ps1
./tools/test.ps1
./tools/run_smoke.ps1
```

On macOS, run each script through PowerShell 7, for example `pwsh ./tools/test.ps1`.

The primary release target is itch.io Web on desktop Chromium and Firefox. Use `./tools/export_web.ps1` and `./tools/serve_web.ps1` for local Web builds; opening `build/web/index.html` directly is not a valid Web test.

For HTTPS testing on a phone, use the VS Code **Test Web on Phone (HTTPS + QR)**
task or follow [`docs/WEB_PHONE_TESTING.md`](docs/WEB_PHONE_TESTING.md).

## Documentation

- `docs/GAME_DESIGN.md` describes player-facing rules and invariants.
- `docs/ARCHITECTURE.md` describes ownership boundaries and extension paths.
- `docs/ASSET_NOTES.md` records visual asset constraints and notes.
- `docs/RELEASE_CHECKLIST.md` lists release/export gates.
- `docs/WEB_PHONE_TESTING.md` documents trusted local HTTPS phone testing.
- `tools/README.md` documents development commands.
- `AGENTS.md` contains operating instructions for coding agents.
