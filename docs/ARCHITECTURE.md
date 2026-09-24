# Architecture

## 5. Build and Icon Assets

`assets\app.ico` is the single canonical application icon for the WPF window,
taskbar, and compiled `ScanMe.exe`. It is copied once from the owner's original
`scan me!.ico`; the original remains unchanged. `build_exe.ps1` embeds this
asset into the executable, and `build_icon.ps1` preserves it as the canonical
output instead of silently replacing it with older PNG-derived artwork.

**Windows Explorer cache note:** Windows caches executable icons. After
rebuilding `ScanMe.exe`, run `ie4uinit.exe -show` (or restart Explorer) before
judging the Explorer file icon; otherwise a stale icon may be displayed.

## 6. HTML tree Open action

The exported HTML tree provides a row-only custom context menu. Right-clicking
a folder or file row suppresses the browser menu and offers the appropriate
Open action plus **Copy Path**. The menu closes on outside click, Escape,
scrolling, or another right-click. The page background keeps the browser's
normal context menu. Existing left-click expand/collapse, search, and copy
controls are not changed.

Open actions navigate to a local custom URL in this form:

    scanme://open?path=<encodeURIComponent(full Windows path)>

The path is generated with backslashes and URL-encoded, so spaces, `!`, and
Unicode are safe. A toast is shown before navigation with the one-time
registration reminder. The first browser use may show the expected
**“Open this app / PowerShell?”** confirmation; that browser safety prompt is
not an application error.

Windows URI normalization can insert `/` before the query when dispatching a
custom-scheme authority URL (`scanme://open?path=...` may reach the registered
handler as `scanme://open/?path=...`). The opener logs that exact raw value,
normalizes only this known transport form back to `scanme://open?path=...`, and
then applies strict validation. The HTML export guard separately rejects any
malformed protocol reference in the generated file.

## 7. Custom protocol components

- `tools\ScanMeOpener.ps1` accepts exactly one `scanme://open?path=...` URL,
  validates the encoded path, requires an absolute existing path, then opens a
  folder with `explorer.exe` or a file with `Invoke-Item`. It logs all steps to
  `%TEMP%\scanme_opener.log`, displays errors in red, and pauses before exiting
  on failure. It rejects all other inputs with exit code 1 and performs no
  network or unrelated actions.
- `tools\test_opener.ps1` manually invokes the opener with a local path in a
  visible PowerShell window.
- `tools\diagnose_protocol.ps1` checks the HKCU registration, verifies a test
  path, invokes the opener, and prints the opener log.
- `tools\register_protocol.ps1` registers `HKCU\Software\Classes\scanme` for the
  current user, including the `URL Protocol` value and the absolute PowerShell
  command that invokes `ScanMeOpener.ps1`. It is idempotent, requires no
  administrator rights, and accepts `-DebugMode` to add `-NoExit` temporarily.
- `tools\unregister_protocol.ps1` removes the current user's `scanme` registry
  key cleanly.

The owner should run registration manually once:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\register_protocol.ps1"
