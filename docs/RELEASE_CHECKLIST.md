# Claim Earth Web Release Checklist

Use this only for a release candidate. Normal feature work follows the smaller test
matrix in `docs/ARCHITECTURE.md`.

## Web Build

1. Run `.\tools\ci.ps1 -Milestone`.
2. Confirm `build\web\export-status.txt` and `build\web\chromium-smoke.png` were generated.
3. Review `build\web\chromium-smoke.stderr.log` for unexpected runtime/browser errors if the smoke gate fails.
4. Start a local preview with `.\tools\serve_web.ps1` and open
   `http://127.0.0.1:8936/index.html`.

## Automation Expectations

- `.\tools\test.ps1` is the default fast gate during development.
- `.\tools\test_performance.ps1` guards against structural frame-loop regressions.
- `.\tools\smoke_web.ps1` verifies exported shell and payload loading.
- `.\tools\smoke_chromium.ps1` verifies browser startup, screenshot capture, and console cleanliness.

## Browser QA

- Chromium-family browser:
  - Start a run.
  - Move, jump, hook, shorten/lengthen rope, and throw each item.
  - Plant a valid flag, confirm a name, and verify the result screen.
  - Return to menu and verify the corner `Best:` label plus the leaderboard panel.
- Firefox:
  - Repeat the same loop once Firefox is available on the release machine.

## Itch.io Packaging

- Zip the contents inside `build/web` so `index.html` is at the ZIP root, then upload
  that ZIP as a browser-playable file.
- Set the embed to responsive mode with keyboard focus enabled.
- Mention keyboard/mouse controls and browser storage behavior in the page copy.

## Environment Note

The automated browser smoke uses an installed Chromium-compatible browser. Firefox
is a manual release check unless a Firefox automation path is added to `tools/`.
