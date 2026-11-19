# App Links / deep link setup — Domino Shak

**Date:** 2026-11-19  
**Status:** **Deep-link handling implemented and tested with limitations (emulator cold/warm, local browser). Verified Android App Links are NOT available** — the production Asset Links file cannot be generated without the Play App Signing fingerprint and direct `/.well-known/` JSON serving is blocked by the host's JavaScript challenge. The static web build was deployed to the public host on 2026-11-19 (see `WEB_DEPLOYMENT_GUIDE.md`), but **no `assetlinks.json` was uploaded**, no hosting setting was changed, and no Play Console action was performed.

---

## Status categories used in this document

- **Implemented** — code/manifest entries exist in the build.
- **Tested successfully** — recorded passing test with named evidence.
- **Tested with limitations** — emulator or local-browser evidence, not verified App Links.
- **Not tested** — no recorded test.
- **Blocked by hosting** — requires a host-side change outside our control.
- **Requires approval or external config** — needs the signing fingerprint or a decision.

---

## 1. Decisions already recorded

| Topic | Decision |
|---|---|
| Public host | `https://liardominoes.gt.tc/` |
| Invitation / universal link | `https://liardominoes.gt.tc/?room=CODE` |
| Timing | Build deep-link handling now; verify App Links later |
| Signing | Play App Signing selected |
| Production fingerprint | **Not available yet** — must not be invented |
| Hosting challenge | Direct JSON serving for `/.well-known/assetlinks.json` is **Blocked by hosting** |
| Static web build | Deployed to public host 2026-11-19 (`?room=CODE` verified live) |
| `assetlinks.json` | Intentionally **not** uploaded — no real fingerprint and `/.well-known/` serves a JS challenge |
| Play upload / publish | Not performed / not authorized |

Consequence: deep links were built and tested locally, but **verified Android App Links must not be claimed as working**.

---

## 2. Implemented behaviour

### 2.1 Invitation generation — `lib/bridge.dart` — Implemented

- `kPublicGameOrigin = 'https://liardominoes.gt.tc'`.
- `inviteUrlFor(code) => '$kPublicGameOrigin/?room=$CODE'` — no `localhost` anywhere.
- Native **copy** puts the full invitation URL on the clipboard; native **share** sends the full URL plus the room code as a fallback for people without the link host. Example share text includes: "لو عندك التطبيق هيفتح الطاولة مباشرة. لو لأ، اللينك هيفتح نسخة المتصفح. كود الطاولة: $roomCode".
- Room codes are validated before use (`^[A-Z0-9]{4,8}$`).

### 2.2 Link parsing — `lib/deep_link.dart` — Implemented

`parseInviteRoomCode(raw)` returns a code only if:

- the URI parses;
- the scheme is `https` (HTTP rejected);
- the host is exactly `liardominoes.gt.tc`;
- the `room` query parameter matches `^[A-Z0-9]{4,8}$` after uppercasing.

Otherwise it returns `null` — an invalid invite never creates a room.

`DeepLinkCoordinator` (singleton):

- `MethodChannel('com.dominoshak.domino_shak/deeplink')`, method `getInitialLink` for the cold-start code;
- `EventChannel('com.dominoshak.domino_shak/deeplink_events')` for warm starts / new intents;
- validates every incoming URL with `parseInviteRoomCode` and exposes valid codes on a `rooms` stream;
- channel errors are swallowed so deep links can never break the game.

### 2.3 Native Android handling — `MainActivity.kt` — Implemented

- The incoming intent is captured **before `super.onCreate`**, fixing a race where Flutter/Dart called `getInitialLink` during engine setup.
- `onNewIntent` handles warm starts.
- `getInitialLink` returns the captured cold-start URL.
- An `EventChannel` emits URLs for warm starts / new intents.
- `singleTop` launch mode is used.

### 2.4 Manifest — `AndroidManifest.xml` — Implemented

A `VIEW` / `BROWSABLE` / `DEFAULT` intent filter with `android:autoVerify="true"` for `https://liardominoes.gt.tc/` is present alongside the `MAIN`/`LAUNCHER` filter. `MODIFY_AUDIO_SETTINGS` (voice fix) is also declared. **The filter is present; App Links verification still depends on Asset Links (§3).**

### 2.5 WebView join behaviour — `lib/web_shell.dart` + `assets/web/index.html` — Implemented

- The WebView still loads only the local origin `http://localhost:8080/index.html?room=CODE&auto=1`; it never loads the external URL or `file://`.
- `?room=CODE` is pre-filled; the `auto=1` flag means "arrived via an invite".
- **Auto-join happens only if a saved name exists** in `localStorage`; otherwise the game shows the manual join screen with the code pre-filled.
- An invitation **never creates a new room** — it only joins the invited table.
- Unknown hosts/schemes/malformed codes are ignored and fall back to the home screen.

---

## 3. Asset Links template — NOT GENERATED as a real file

Publish path (only when a real file exists):

`https://liardominoes.gt.tc/.well-known/assetlinks.json`

Template present in the generated web project:

`domino_shak_web/.well-known/assetlinks.json.template`

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.dominoshak.domino_shak",
      "sha256_cert_fingerprints": [
        "REPLACE_WITH_PLAY_APP_SIGNING_SHA256_CERTIFICATE_FINGERPRINT"
      ]
    }
  }
]
```

### Important — no placeholder file is present

**Status: Requires approval or external config.**

`tools/sync_web_assets.sh` writes a real `assetlinks.json` **only** when `PLAY_APP_SIGNING_SHA256` is supplied and validates as a 32-byte hex fingerprint. When the variable is absent, the script **removes any existing `assetlinks.json`** and warns that only `assetlinks.json.template` is present. There is deliberately **no placeholder `assetlinks.json`** in `domino_shak_web/.well-known/`. Do not create one by hand, do not upload the template as `assetlinks.json`, and do not upload a placeholder — Android would reject it and it could be mistaken for a configured file.

Do not:

- invent a Play App Signing fingerprint;
- copy a fingerprint from another app or tutorial;
- use the debug or upload-key fingerprint as the production fingerprint;
- publish the template as a real association file.

---

## 4. Hosting requirement — Blocked by hosting

The Phase 0 audit found:

- a request to `/.well-known/assetlinks.json` first hits the JavaScript cookie challenge;
- after the challenge cookie is set, the path resolves to an InfinityFree 404 page;
- no asset file is deployed.

Google's verifier does not solve a JavaScript challenge. Required before verification is possible:

1. Host confirms `/.well-known/` can bypass the challenge.
2. The file is served with `application/json` content type.
3. A browser and a plain HTTP client both receive the exact JSON body without a challenge page.
4. The URL is reachable over HTTPS with the valid certificate.

**Status: Blocked by hosting until all four checks pass.** No hosting change has been made and no verification is claimed.

---

## 5. Test evidence

| Check | Environment | Result / evidence | Status |
|---|---|---|---|
| `flutter analyze` clean; `flutter test` 12/12 | Local checkout | Pass, includes invitation URL/parse tests | Tested successfully |
| `inviteUrlFor` uses public host, never localhost | `flutter test` (`bridge_test.dart`) | Pass | Tested successfully |
| `parseInviteRoomCode` accepts HTTPS public host + valid code, rejects HTTP/other host/short/missing code | `flutter test` (`bridge_test.dart`) | Pass | Tested successfully |
| Cold start with `https://liardominoes.gt.tc/?room=COLD77` | Emulator `emulator-5554` | `COLD77` pre-filled, invite banner shown | **Tested with limitations** (emulator; not installed-app verification) |
| Warm start with `WARM88` | Emulator `emulator-5554` | `WARM88` pre-filled | **Tested with limitations** |
| `?room=TEST12` prefill in browser | Local `python3 -m http.server 8765` | `TEST12` pre-filled | **Tested with limitations** (local server, not public host) |
| Auto-join only when a saved name exists | Code path / local checks | Invite never creates a room; manual join otherwise | Implemented (no dedicated gameplay test recorded) |
| Production Play App Signing fingerprint | Play Console | Not available | Requires approval or external config |
| Real `assetlinks.json` generated | `domino_shak_web/` | Not generated; only `.template` present | Requires approval or external config |
| Direct JSON serving without challenge | Public host | Unconfirmed / absent | Blocked by hosting |
| Verified App Links | Android verifier | Not verified | **Not verified — must not be claimed** |

See `PHASE5_FEATURE_REPORT.md` for the consolidated evidence and emulator-vs-physical-device split.

---

## 6. Remaining steps (all blocked or pending)

1. Obtain the production Play App Signing SHA-256 fingerprint. **Blocked — not available.**
2. Regenerate with `PLAY_APP_SIGNING_SHA256` set so a real `assetlinks.json` exists. **Pending.**
3. Get hosting to exempt `/.well-known/` from the cookie challenge and serve JSON directly. **Blocked by hosting.**
4. Publish the real asset file at the exact path. **Pending — asset file intentionally not uploaded** (the static web build was deployed via the hidden-prompt FTPS tool, but no `assetlinks.json` exists to publish).
5. Verify with Google's App Links assistant / `adb` and by opening a link from an external app (chat, browser, notes). **Not tested.**
6. Re-test cold start, warm start, background/resume, invalid code, unknown host, and web fallback with a verifiable link. **Partially tested on emulator only.**
7. Only after all checks pass may App Links be described as verified.

No step above has been completed for verified App Links.

---

## 7. Limitations and blockers

- Deep-link URL handling is implemented and emulator-tested; **verified App Links are not available**.
- The production `assetlinks.json` cannot be finalized without the Play app-signing fingerprint; **no placeholder file is present** and none should be uploaded.
- The host's JavaScript challenge likely blocks Google's verifier; treated as blocked, not as a small fix.
- The static web build was deployed by the maintainer via the hidden-prompt FTPS tool; no `assetlinks.json` was uploaded and no hosting setting was changed.
- No Play upload or AAB publish was performed.
- Until verification succeeds, treat links as ordinary deep links for local testing only.
- App Links are Android-only in this project; iOS is out of scope.

---

## 8. Related documents

- `WEB_DEPLOYMENT_GUIDE.md` — host, generated source files, upload checklist and asset-path fixes.
- `NETWORK_COMPATIBILITY_MATRIX.md` — which connection modes are tested.
- `PHASE5_FEATURE_REPORT.md` — consolidated test evidence.
- `PROJECT_AUDIT_AND_NEXT_STEPS.md` — Phase 0 findings and developer decisions.
