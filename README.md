# Claim Earth

Claim Earth is a small Godot arcade game about descending through a generated hex cave with bombs, a grappling hook, and a flag used to bank the run's depth. The base game is implemented; current work is maintenance, portfolio polish, and feature development.

## Quick Start

Use Godot 4.6.3 with the Compatibility renderer. From the repository root:

```powershell
.\tools\import.ps1
.\tools\test.ps1
.\tools\run_smoke.ps1
```

The primary release target is itch.io Web on desktop Chromium and Firefox. Use `.\tools\export_web.ps1` and `.\tools\serve_web.ps1` for local Web builds; opening `build/web/index.html` directly is not a valid Web test.

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
