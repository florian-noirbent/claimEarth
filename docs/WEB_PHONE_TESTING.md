# Testing the Web Build on a Phone

Use the local HTTPS phone server to test the same Web export that is uploaded to
itch.io. The phone and development computer must be on the same LAN. A public
tunnel is not required.

## Run from VS Code

Choose either:

- **Terminal > Run Task > Test Web on Phone (HTTPS + QR)**.
- **Run and Debug > Launch Phone Web Test (HTTPS + QR)**.

The command rebuilds `build/web`, replaces the previously managed phone server,
prints the HTTPS URL and an ASCII QR code, and then exits while the server keeps
running. Scan the QR code with the phone. Generated responses use `no-store`
headers, and every run uses a unique URL path. Relative JavaScript, WebAssembly,
and PCK URLs therefore change with the build, so a phone cannot reuse payloads
cached by an earlier test server.
On the first run, the task installs the pinned `qrcode` helper into ignored
`build/tools`; Python and internet access are required for that one-time step.

The equivalent PowerShell commands are:

```powershell
.\tools\run_phone_web.ps1
.\tools\stop_phone_web.ps1
```

Use `-Debug` for a debug export, `-SkipExport` to serve the existing build, or
`-Address 192.168.1.224` if automatic LAN-address detection chooses the wrong
adapter.

## One-Time HTTPS Certificate Setup

Godot Web requires a secure context on a phone. Create a locally trusted
certificate for the computer's LAN address with `mkcert`:

```powershell
$address = "192.168.1.224"
New-Item -ItemType Directory -Force build/local-https
mkcert -install
mkcert -cert-file "build/local-https/$address.pem" `
  -key-file "build/local-https/$address-key.pem" $address localhost 127.0.0.1 ::1
mkcert -CAROOT
```

Copy `rootCA.pem` from the directory printed by `mkcert -CAROOT` to Android and
install it as a **CA certificate**. Do not install the leaf `$address.pem` as a
VPN/app certificate. Chrome may need to be restarted after installing the CA.
The generated certificate files stay under ignored `build/local-https`; recreate
them when the LAN address changes or the certificate expires.

If Windows Firewall prompts for Python access, allow it on private networks. Do
not expose port 8936 to the internet.

## Logs and Troubleshooting

- Phone HTTP requests and Python server errors:
  `build/logs/phone-server.stderr.log`.
- Server session details and current URL:
  `build/logs/phone-web-session.json`.
- Exported-game Start regression:
  `.\tools\smoke_exported_game.ps1`.
- Browser presentation smoke:
  `.\tools\smoke_chromium.ps1`.

If the page opens but Start does nothing, reproduce once on the phone, then
inspect the phone-server request log to confirm the HTML, PCK, WebAssembly, and
JavaScript payloads were all requested. The HTTP server log cannot contain
Godot or JavaScript runtime errors. For an Android-only failure, enable USB
debugging, connect the phone, open `chrome://inspect/#devices` in desktop Chrome,
and inspect the phone tab's Console. Reproduce on desktop with
`.\tools\run_web_debug.ps1` when the failure is not mobile-specific.
