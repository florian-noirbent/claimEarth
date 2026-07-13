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
- `.\tools\smoke_exported_game.ps1` verifies the exported PCK can start a run
  and reach `PLAYING` without missing resources or script parse errors.
- `.\tools\smoke_web.ps1` verifies the exported game plus shell and payload loading.
- `.\tools\smoke_chromium.ps1` verifies browser startup, screenshot capture, and console cleanliness.

The Web preset uses Godot's `all_resources` mode with no hand-maintained include,
exclude, or dependency list. Keep `build/.gdignore` in place so generated output
does not become project input.

## Browser QA

- Chromium-family browser:
  - Enter and exit fullscreen with the top-right button, including an external
    Back/Escape exit, and confirm the button state follows the browser.
  - Start a run.
  - Confirm the top-left FPS reading updates during active play.
  - Move, jump, hook, shorten/lengthen rope, and throw each item.
  - Plant a valid flag, confirm a name, and verify the result screen.
  - Return to menu and verify the corner `Best:` label plus the leaderboard panel.
- Firefox:
  - Repeat the same loop once Firefox is available on the release machine.
- Android Chromium:
  - In landscape fullscreen, verify partial and cardinal movement on both sticks.
  - Verify simultaneous movement plus item aim/release and hook press/hold/release.
  - Confirm releasing or canceling either touch immediately returns that control to
    neutral without resetting the other finger.

## Itch.io Packaging

- Zip the contents inside `build/web` so `index.html` is at the ZIP root, then upload
  that ZIP as a browser-playable file.
- Set the embed to responsive mode with keyboard focus enabled.
- Mention keyboard/mouse controls and browser storage behavior in the page copy.

## Environment Note

The automated browser smoke uses an installed Chromium-compatible browser. Firefox
is a manual release check unless a Firefox automation path is added to `tools/`.
