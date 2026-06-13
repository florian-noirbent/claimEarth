# Claim Earth Release Checklist

## Web Build

1. Run `.\tools\ci.ps1`.
2. Run `.\tools\smoke_web.ps1`.
3. Start a local preview with `.\tools\serve_web.ps1` and open
   `http://127.0.0.1:8936/index.html`.

## Browser QA

- Chromium-family browser:
  - Start a run.
  - Move, jump, hook, shorten/lengthen rope, and throw each item.
  - Plant a valid flag, confirm a name, and verify the result screen.
  - Return to menu and verify `Earth owned by:` plus the leaderboard panel.
- Firefox:
  - Repeat the same loop once Firefox is available on the release machine.

## Itch.io Packaging

- Upload the contents of `build/web`.
- Set the embed to responsive mode with keyboard focus enabled.
- Mention keyboard/mouse controls and browser storage behavior in the page copy.

## Known Local Limitation

This workstation currently has Python and Chromium-compatible browser coverage for
local smoke. Firefox is not installed, so Firefox verification must happen on the
release machine before final jam upload.
