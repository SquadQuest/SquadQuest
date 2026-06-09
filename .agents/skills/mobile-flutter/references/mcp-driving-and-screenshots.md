# Driving & Screenshotting a Flutter App via the Dart MCP

How an agent launches a Flutter app, drives it (tap / type / scroll), inspects and
debugs it, captures real screenshots, and delivers those screenshots to the user.
Written from hard-won macOS-desktop experience; most of it applies to any target.

The payoff: a **self-verifying loop** — change code, run the app, drive the real UI,
screenshot the result, confirm behavior — without a human touching the mouse.

---

## 0. Mental model

The modern `dart mcp-server` does **not** have a `launch_app` tool. The flow is:

1. **You** launch the app (`flutter run …`) — the agent runs this in a shell, not via MCP.
2. The app exposes a **Dart VM Service** (a.k.a. observatory) and registers with a
   **Dart Tooling Daemon (DTD)**.
3. The MCP connects to the DTD, then drives the app over the VM service using the
   **Flutter Driver** extension and the **widget inspector**.
4. Screenshots come from the **engine** (not OS screen capture), so they work even when
   the window is hidden, backgrounded, or on another Space.

Key MCP tools (load via ToolSearch `select:` if deferred):
`mcp__dart__dtd`, `mcp__dart__flutter_driver_command`, `mcp__dart__widget_inspector`,
`mcp__dart__get_runtime_errors`, `mcp__dart__hot_reload`, `mcp__dart__hot_restart`,
`mcp__dart__pub`, `mcp__dart__analyze_files`.

> The MCP server is long-lived and inherits the environment from when it was spawned. If
> it reports the **wrong SDK** (e.g. an old Dart that can't resolve `pubspec`), the fix is
> to **restart the MCP** so it re-execs against the current PATH (e.g. kill the
> `dart mcp-server` process; the host reconnects it). asdf shims resolve at exec time, so a
> fresh spawn picks up the current `.tool-versions`.

---

## 1. One-time setup: a driver entry point

Flutter Driver commands require the app to call `enableFlutterDriverExtension()`. Add a
dedicated entry point so production `main()` stays clean (see the
`flutter-add-integration-test` skill for the fuller integration-test harness):

```yaml
# pubspec.yaml — flutter pub add --dev flutter_driver  (it's an SDK package)
dev_dependencies:
  flutter_driver:
    sdk: flutter
```

```dart
// test_driver/app.dart
import 'package:flutter_driver/driver_extension.dart';
import 'package:your_app/main.dart' as app;

void main() {
  enableFlutterDriverExtension(); // exposes ext.flutter.driver over the VM service
  app.main();
}
```

**Add `Key`s to anything you'll drive or to repeated controls.** Finding widgets by text
breaks the moment a label appears twice (`ambiguously found multiple matching widgets`).
Give list items / per-row buttons stable keys, ideally derived from a model id:

```dart
TextField(key: const Key('phoneField'), …)
FilledButton(key: const Key('verifyOtpButton'), …)
// repeated controls — key by id so each is uniquely addressable:
IconButton(key: Key('vote_${option.id}'), …)
TextButton(key: Key('confirm_${option.id}'), …)
```

---

## 2. Launch the app

```bash
flutter run test_driver/app.dart -d macos --dart-define=API_BASE_URL=http://localhost:4000 \
  > /tmp/app-run.log 2>&1 &
# wait for the VM Service line, then grab the ws:// URI
grep -oE 'ws://127.0.0.1:[0-9]+/[A-Za-z0-9_=-]+/ws' /tmp/app-run.log | tail -1
# (the log prints "A Dart VM Service on macOS is available at: http://127.0.0.1:PORT/TOKEN/")
```

Run it backgrounded and poll the log for `VM Service on macOS is available` (or
`BUILD FAILED` / `Error`). The **VM service ws URI** is what you screenshot against; the
**DTD** is what the MCP connects to (different ports).

---

## 3. Connect the MCP

```
mcp__dart__dtd  command=listDtdUris
mcp__dart__dtd  command=connect  uri=ws://127.0.0.1:<dtd-port>/<token>
```

**Picking the right DTD when several are listed** (common — every IDE and every
`flutter run` spins one up):

- A terminal `flutter run` produces a DTD with **no `IDE:` field**.
- VS Code's own daemon often has `Workspace Root: /` (no app) — ignore it.
- After `connect`, the response lists connected apps with their VM service `uri`. **Match
  that `uri` to the `ws://…/ws` from your run log** to be sure you're driving *your*
  instance, not someone else's.

---

## 4. Two settings to flip BEFORE you touch anything

These two are responsible for ~90% of "it just hangs / nothing types" frustration:

```
mcp__dart__flutter_driver_command  command=set_frame_sync          enabled=false
mcp__dart__flutter_driver_command  command=set_text_entry_emulation enabled=true
```

- **`set_frame_sync=false`** — By default the driver waits for "no pending frames" after
  each action. A blinking text cursor (or any animation/`Ticker`) keeps frames pending
  **forever**, so a `tap` on a `TextField` returns `Timed out waiting for Flutter Driver
  response`. Disabling frame sync fixes it. Re-assert it after a `hot_restart`.
- **`set_text_entry_emulation=true`** — lets `enter_text` inject into the focused field
  without a real OS keyboard/IME connection.

---

## 5. Drive it

```
# type into the focused field (autofocus, or tap the field first to focus it)
mcp__dart__flutter_driver_command  command=enter_text  text=+12155551000

# tap by key (preferred), text, tooltip, or type
mcp__dart__flutter_driver_command  command=tap  finderType=ByValueKey  keyValueString=verifyOtpButton  keyValueType=String
mcp__dart__flutter_driver_command  command=tap  finderType=ByText      text="Go Paddleboarding"
mcp__dart__flutter_driver_command  command=tap  finderType=ByTooltipMessage text=Increment

# inspect to discover real widgets/keys (don't guess finders)
mcp__dart__widget_inspector  command=get_widget_tree  summaryOnly=true
```

### The biggest desktop gotcha: window focus & text entry

On desktop, the engine routes keystrokes/`enter_text` to the **macOS key (focused)
window only**. Consequences:

- If your driver app is **backgrounded** behind another window (a second app instance, the
  editor, another Space), `enter_text` **silently no-ops** — the call "succeeds" but the
  field stays empty. Taps may also misbehave.
- **Fix:** drive a **single instance that is the sole / frontmost window.** Kill stray
  instances first (`pkill -f "<app>.app/Contents/MacOS/<app>"`, `pkill -f
  "test_driver/app.dart"`). When in doubt, capture a screenshot and *confirm the field
  actually contains your text* before moving on.
- `autofocus: true` only fires on a **fresh build**, not when a screen returns via
  `setState` (e.g. OTP step → back to phone step). If text won't land, the field probably
  isn't focused — tap it first (with `set_frame_sync=false`), or `hot_restart` for a clean
  autofocus.

### Actions that navigate can report a false timeout

Tapping a button that immediately disposes the current screen (login → redirect to home)
often returns `Timed out waiting for Flutter Driver response` **even though the action
succeeded** — the widget the tap was tracking vanished mid-gesture. Don't treat it as
failure: wait, then verify via the server log and/or a fresh screenshot.

### Multi-step recipe (worked end-to-end)

Seed backend state → launch single instance → `dtd connect` → `set_frame_sync=false` +
`set_text_entry_emulation=true` → drive each step, screenshotting between steps to stay in
sync → read any dev secrets (e.g. an OTP) from the **server log**, not the UI:

```bash
grep -oE 'code for \+[0-9]+: [0-9]{6}' /tmp/server-dev.log | tail -1
```

---

## 6. Screenshots — capture a real PNG file

`flutter_driver_command command=screenshot` returns a PNG **inline to the agent** — useful
for the agent to *see*, but it is **not a file** and is **not shown to the user**. To
deliver a screenshot you need a file on disk. Options, worst → best:

| Method | Produces | Caveats |
|---|---|---|
| `flutter_driver_command screenshot` | inline image (agent-only) | not a file, not delivered to user |
| `flutter screenshot --type=skia` | `.skp` Skia picture | **not a viewable image** (header `skiapict`) |
| `flutter screenshot --type=device` | PNG | OS capture — needs Screen Recording perm; **fails if window off-screen** |
| `uvx screenshot <app>` / `screencapture` | PNG | OS capture — Screen Recording perm; only captures **visible** windows; `osascript` window control needs Accessibility perm |
| **VM-service `_flutter.screenshot` RPC** | **PNG file** | **engine render — no OS perms, works off-screen. Use this.** |

### The reliable method: `_flutter.screenshot` over the VM service

The engine exposes a screenshot RPC that returns a base64 PNG. Connect to the VM service
websocket, call it, decode to a file. Drop this script in `.scratch/shot.mjs`:

```js
// bun .scratch/shot.mjs <ws-uri> <out.png>
import { writeFileSync } from 'node:fs'
const [, , wsUri, out] = process.argv
const ws = new WebSocket(wsUri)
ws.addEventListener('open', () =>
  ws.send(JSON.stringify({ jsonrpc: '2.0', id: 1, method: '_flutter.screenshot' })))
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data)
  if (m.id !== 1) return
  if (m.error) { console.error(JSON.stringify(m.error)); process.exit(1) }
  writeFileSync(out, Buffer.from(m.result.screenshot, 'base64'))
  console.log('wrote', out); process.exit(0)
})
ws.addEventListener('error', (e) => { console.error(e.message ?? e); process.exit(1) })
setTimeout(() => { console.error('timeout'); process.exit(1) }, 15000)
```

```bash
WS=$(grep -oE 'ws://127.0.0.1:[0-9]+/[A-Za-z0-9_=-]+/ws' /tmp/app-run.log | tail -1)
bun .scratch/shot.mjs "$WS" .scratch/shot.png
file .scratch/shot.png   # → PNG image data, WxH  (sanity check before sending)
```

It needs no DTD connection and no OS permissions, and renders the engine's current frame
regardless of window visibility. To screenshot a *specific* running instance among several,
point the script at that instance's VM service `ws` URI (get it from its run log, or from
`dtd connect`'s connected-apps list).

### Deliver it to the user

Capturing a file is only half the job — the inline MCP screenshots never reach the user.
Use your agent's file-delivery / remote-control mechanism to send the PNG (e.g. Claude
Code's file-send tool). Sanity-check with `file <png>` first; a 0-byte or `skiapict` file
means capture failed. Send a small curated set with captions rather than every frame.

---

## 7. Debugging

- **`mcp__dart__get_runtime_errors`** surfaces *unhandled* errors only. An exception caught
  by a `try/catch` (e.g. a screen that shows "Something went wrong") **won't appear** here.
  To see it: temporarily render the real error (`catch (e) { setState(() => _error = '$e'); }`),
  `hot_reload`, reproduce, read it off the screenshot, then revert. This is how you turn a
  vague UI message into the actual `PlatformException(... -34018 ...)`.
- **`hot_reload`** applies code changes, keeps state. **`hot_restart`** resets state —
  required when you change something built once at startup (e.g. a provider-constructed
  singleton's options); a hot reload won't pick that up.
- The **server log** is your friend for backend-driven flows (request outcomes, dev OTP
  codes, status codes). Cross-check it against the UI.
- After editing Dart, `mcp__dart__analyze_files` (or `flutter analyze`) before re-running.

---

## 8. macOS desktop running checklist

Running an unsigned debug build for driving has sharp edges (details in
[gotchas.md](gotchas.md)):

- **Outbound network** needs `com.apple.security.network.client` in
  `macos/Runner/{DebugProfile,Release}.entitlements`.
- **`flutter_secure_storage`** on an unsigned build fails with `-34018`
  (errSecMissingEntitlement — the data-protection keychain wants app signing) or `-25308`
  (errSecInteractionNotAllowed). Mitigate for local/CI dev:
  `MacOsOptions(usesDataProtectionKeychain: false)`, drop `app-sandbox` from
  **DebugProfile** only (Release keeps it; distribution needs real signing), and make token
  storage tolerate failures (degrade to an in-memory session) so auth never hard-fails.
- Keep one app window during a driving session; close the editor's debug instance.

---

## TL;DR sequence

```
flutter run test_driver/app.dart -d macos > /tmp/app-run.log 2>&1 &   # single instance!
# grab ws:// from the log
dtd listDtdUris → connect (match the app uri)
flutter_driver_command set_frame_sync=false
flutter_driver_command set_text_entry_emulation=true
# drive: enter_text / tap by Key; read dev secrets from the server log
bun .scratch/shot.mjs "<vm-ws-uri>" .scratch/shot.png   # real PNG, any window state
# deliver shot.png to the user via the remote-control file-send tool
```
