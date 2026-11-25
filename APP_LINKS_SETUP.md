# App Links / deep link setup — Domino Shak

**Date:** 2026-11-19 (updated 2026-11-25)  
**Status:** **Deep-link handling implemented and tested with limitations (emulator cold/warm, local browser).** The real `assetlinks.json` is now generated from the Play App Signing fingerprint and **published live** on 2026-11-25. The host's JavaScript challenge still answers browser-like and plain clients, but Google's verifier and Googlebot user agents receive the JSON directly (`200`, `application/json`, no redirect). Re-verification in Play Console is pending.

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
| Production fingerprint | **Available** — Play App Signing SHA-256 recorded in §3 |
| Hosting challenge | Googlebot / App Links verifier agents are served the file directly; browser-like agents still get the JS challenge |
| Static web build | Deployed to public host 2026-11-19 (`?room=CODE` verified live) |
| `assetlinks.json` | **Generated and published 2026-11-25** — `200`, `application/json`, no redirect |
| Play upload / publish | AAB `1.0.5` (code 5) uploaded to internal testing; production not yet released |

Consequence: the association file exists and is served correctly to Google. Final confirmation depends on Play Console re-verification and, for on-device behaviour, a physical-device check.

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

A `VIEW` / `BROWSABLE` / `DEFAULT` intent filter with `android:autoVerify="true"` for `https://liardominoes.gt.tc/` is present alongside the `MAIN`/`LAUNCHER` filter. `MODIFY_AUDIO_SETTINGS` (voice fix) is also declared. The matching Asset Links file is now published (§3), so Android can verify the association at install time.

### 2.5 WebView join behaviour — `lib/web_shell.dart` + `assets/web/index.html` — Implemented

- The WebView still loads only the local origin `http://localhost:8080/index.html?room=CODE&auto=1`; it never loads the external URL or `file://`.
- `?room=CODE` is pre-filled; the `auto=1` flag means "arrived via an invite".
- **Auto-join happens only if a saved name exists** in `localStorage`; otherwise the game shows the manual join screen with the code pre-filled.
- An invitation **never creates a new room** — it only joins the invited table.
- Unknown hosts/schemes/malformed codes are ignored and fall back to the home screen.

---

## 3. Asset Links file — generated and published

Publish path:

`https://liardominoes.gt.tc/.well-known/assetlinks.json`

Generated file (also committed at `domino_shak_web/.well-known/assetlinks.json`):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.dominoshak.domino_shak",
      "sha256_cert_fingerprints": [
        "47:23:91:28:46:C2:5D:AB:A6:6E:C8:42:13:86:D1:E8:33:20:28:18:B5:F6:89:63:10:40:F8:59:A3:38:4B:EF",
        "83:6A:88:B3:88:B3:13:DD:13:CC:2C:33:3C:52:CA:71:AB:A9:25:C6:73:45:4B:8E:E1:1C:D8:44:A8:93:4A:7C"
      ]
    }
  }
]
```

- First fingerprint — **Play App Signing** certificate (from Play Console → App integrity → App signing). This is the one Google verifies for Play-installed builds.
- Second fingerprint — **upload key** certificate, so local/sideloaded release builds also verify.

### How it is regenerated

```bash
PLAY_APP_SIGNING_SHA256="47:23:91:28:46:C2:5D:AB:A6:6E:C8:42:13:86:D1:E8:33:20:28:18:B5:F6:89:63:10:40:F8:59:A3:38:4B:EF" \
UPLOAD_KEY_SHA256="83:6A:88:B3:88:B3:13:DD:13:CC:2C:33:3C:52:CA:71:AB:A9:25:C6:73:45:4B:8E:E1:1C:D8:44:A8:93:4A:7C" \
bash tools/sync_web_assets.sh
python3 tools/ftps_deploy.py --deploy --credentials-file /home/ali/.config/domino_shak/ftps-credentials
```

`tools/sync_web_assets.sh` validates that each value is a 32-byte hex fingerprint, accepts input with or without colons, and always emits colon-separated uppercase hex (the format Android expects). `UPLOAD_KEY_SHA256` is optional. With neither variable set the script removes any existing `assetlinks.json` and warns — it never writes a placeholder. `tools/ftps_deploy.py` publishes only a real `.well-known/assetlinks.json`; the `.template` file never reaches the live host.

These fingerprints are public data (they appear in the live file) and are safe to keep in the repository. Private keys and keystore passwords are never stored here.

Do not:

- invent a Play App Signing fingerprint;
- copy a fingerprint from another app or tutorial;
- publish `assetlinks.json.template` as the real association file.

---

## 4. Hosting behaviour — verified 2026-11-25

Live checks against `https://liardominoes.gt.tc/.well-known/assetlinks.json`:

| Client | Result |
|---|---|
| `Google-Android-App-Links-Verifier/1.0` | `200`, `Content-Type: application/json`, 0 redirects, exact JSON body |
| `Googlebot/2.1` | `200`, `Content-Type: application/json`, 0 redirects, exact JSON body |
| Browser-like User-Agent | `200`, `text/html` — InfinityFree `aes.js` cookie challenge page |
| Plain `curl` / `python-requests` (no or generic UA) | Connection reset by the host's bot protection |

So Google's verifier is served the file correctly. The remaining risk is on-device verification by Google Play services if it presents a non-whitelisted agent and receives the challenge page. If Play Console re-verification passes but links still open in the browser on a device, the durable fix is to move the site to a host without a JavaScript challenge (e.g. GitHub Pages or Cloudflare Pages) and rebuild with the new host in the manifest and `kPublicGameOrigin`.

The live file's SHA-256 is `54e8a84317ab7fc989fb99a5d7b0dedf6cb5e2b51d4102299c6b2711554168cc` and matches the local generated file byte for byte.

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
| Production Play App Signing fingerprint | Play Console → App integrity | `47:23:91:…:4B:EF` recorded | Tested successfully |
| Real `assetlinks.json` generated | `domino_shak_web/` | Generated with app-signing + upload-key fingerprints, JSON validated | Tested successfully |
| Live JSON serving | Public host | `200`, `application/json`, 0 redirects for Googlebot and App Links verifier UAs | Tested successfully |
| Live JSON integrity | Public host | SHA-256 `54e8a843…68cc` matches local file | Tested successfully |
| Browser-like / plain client | Public host | JS challenge page / connection reset | Blocked by hosting |
| Play Console deep-link re-verification | Play Console | Not run yet | Pending |
| Verified App Links on a device | Android verifier | No physical device connected | **Not verified — must not be claimed** |

See `PHASE5_FEATURE_REPORT.md` for the consolidated evidence and emulator-vs-physical-device split.

---

## 6. Remaining steps

1. ~~Obtain the production Play App Signing SHA-256 fingerprint.~~ **Done 2026-11-25.**
2. ~~Regenerate with `PLAY_APP_SIGNING_SHA256` set so a real `assetlinks.json` exists.~~ **Done 2026-11-25.**
3. ~~Publish the real asset file at the exact path.~~ **Done 2026-11-25** (see §3–§4).
4. Re-run the deep-link verification in Play Console. **Pending — do this now.**
5. Verify on a physical device: install the Play build, open `https://liardominoes.gt.tc/?room=CODE` from another app, and confirm the app opens the table. **Not tested — no device connected.**
6. Re-test cold start, warm start, background/resume, invalid code, unknown host, and web fallback with a verifiable link. **Partially tested on emulator only.**
7. If Play Console still fails because of the host's challenge, move the site to a challenge-free host and rebuild with the new host. **Fallback, not started.**
8. Only after all checks pass may App Links be described as verified.

---

## 7. Limitations and blockers

- Deep-link URL handling is implemented and emulator-tested; **on-device App Links verification is not confirmed**.
- The real association file is live and served correctly to Google's agents; **browser-like and plain HTTP clients still receive the InfinityFree JavaScript challenge**, which is the main remaining risk for on-device verification.
- The static web build is deployed by the maintainer via the hidden-prompt FTPS tool; publishing `assetlinks.json` required a small fix to `tools/ftps_deploy.py`, which previously skipped `/.well-known/` entirely.
- No physical Android device is connected, so end-to-end link behaviour is unverified.
- App Links are Android-only in this project; iOS is out of scope.

---

## 8. Related documents

- `WEB_DEPLOYMENT_GUIDE.md` — host, generated source files, upload checklist and asset-path fixes.
- `NETWORK_COMPATIBILITY_MATRIX.md` — which connection modes are tested.
- `PHASE5_FEATURE_REPORT.md` — consolidated test evidence.
- `PROJECT_AUDIT_AND_NEXT_STEPS.md` — Phase 0 findings and developer decisions.
