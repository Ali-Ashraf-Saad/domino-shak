# Phase 5 feature report — invitations, LAN, web project, voice, chat

**Date:** 2026-11-19  
**Scope:** documentation report only. No source, HTML, Dart, Kotlin, config, or deployment file was changed while writing this report. It consolidates the implementation and test evidence completed in this phase and separates **emulator**, **local/browser**, and **physical-device** results honestly.

> **Update 2026-11-25:** the App Links blocker described below was resolved. The Play App Signing fingerprint was obtained, a real `assetlinks.json` was generated and deployed, and it is served with `200`, `application/json`, no redirect to Googlebot and the App Links verifier. See `APP_LINKS_SETUP.md` §3–§4 for current state. Play Console re-verification and on-device testing are still pending.

---

## 1. Status categories

- **Implemented** — code/config exists and is in the build.
- **Tested successfully** — a recorded passing check with named evidence.
- **Tested with limitations** — partial evidence (unit-only, emulator, one device, local server), not the full target scenario.
- **Not tested** — no recorded test exists.
- **Blocked by hosting** — requires a host-side change outside our control.
- **Requires approval or external config** — needs credentials, a signing fingerprint, or a decision.

---

## 2. Feature summary

| Feature | Implementation status | Test status |
|---|---|---|
| Invitation URLs / App Link plumbing | Implemented | Tested with limitations (unit + emulator + local browser); verified App Links blocked |
| Offline LAN transport (Android↔Android) | Implemented | Tested with limitations (unit + single-device emulator); two-device offline Not tested |
| Web deployable project (`domino_shak_web/`) | Implemented and deployed to the public host | Tested successfully (local `http.server` + live public-host browser checks) |
| Voice capture instrumentation + reliability | Implemented | Tested with limitations (one-device diagnostic build earlier); measurements pending |
| Chat safety + typing indicator | Implemented | Code-level checks; no dedicated gameplay test for typing |
| Build / regression | Implemented | Tested successfully (analyze clean, tests 12/12, release APK built + installed on emulator) |

---

## 3. Emulator and local test evidence (`emulator-5554`, local checkout/browser)

Each row lists the test, environment, result, and evidence.

| # | Test | Device / environment | Result | Evidence |
|---|---|---|---|---|
| E1 | Static analysis | Local checkout | **Pass** — `flutter analyze` clean | Flutter CLI output |
| E2 | Full unit/widget test suite | Local checkout | **Pass** — `flutter test` **12/12** | Flutter CLI output |
| E3 | Room-code validation + per-launch token + mobile shim tests | Local checkout (`test/bridge_test.dart`) | **Pass** (8 tests) | `flutter test` output |
| E4 | Invitation URL uses public host, never localhost | Local checkout (`bridge_test.dart`) | **Pass** — `inviteUrlFor('ABCD') == 'https://liardominoes.gt.tc/?room=ABCD'` | Unit test |
| E5 | Invitation parsing accepts only valid HTTPS public-host codes | Local checkout (`bridge_test.dart`) | **Pass** — accepts lowercase/uppercase valid codes and `&auto=1`; rejects HTTP, other host, short/missing codes, null | Unit test |
| E6 | LAN relay routes messages between two simulated clients | Local checkout (`test/lan_service_test.dart`, loopback) | **Pass** — two-client `register` + `relay` | Unit test |
| E7 | LAN relay handles unknown peer without crashing | Local checkout (`lan_service_test.dart`) | **Pass** — `error`/`peer-unavailable`, no crash | Unit test |
| E8 | Cold start with `https://liardominoes.gt.tc/?room=COLD77` | Emulator `emulator-5554` | **Pass with limitation** — `COLD77` pre-filled and invite banner shown | Emulator run (not a verified App Link) |
| E9 | Warm start with `WARM88` | Emulator `emulator-5554` | **Pass with limitation** — `WARM88` pre-filled | Emulator run (new intent path) |
| E10 | Invite never creates a room; auto-join only with a saved name | Code path + local checks | **Implemented** — otherwise manual join with code pre-filled | Code inspection; no dedicated gameplay test |
| E11 | LAN mode selected, local room created, lobby shows IP + code | Emulator `emulator-5554` | **Pass with limitation** — lobby showed `طاولة محلية — ... IP: 10.0.2.16 والكود 3CWHV` (`10.0.2.16` is the emulator NAT address, not a LAN address) | Emulator run |
| E12 | Web project generated from canonical source | Local checkout, `tools/sync_web_assets.sh` | **Pass** — `domino_shak_web/` created; historical `index.html` hash unchanged (`d9d711ea…`); bundled hash re-verified (`ab7c610e…`) | Script run + `sha256sum` |
| E13 | Corrected asset paths | Local `python3 -m http.server 8765` | **Pass** — fonts in `fonts/`, PeerJS in `vendor/`; no 404s (earlier `assets/` path caused 404s and was fixed) | Local server check |
| E14 | Bundled PeerJS loads in browser | Local server (browser console) | **Pass** — `typeof Peer === 'function'` | Browser console |
| E15 | Mode selector and no console errors | Local server (browser) | **Pass** — mode selector present, no console errors | Browser console |
| E16 | `?room=TEST12` prefill on local web build | Local server (browser) | **Pass** — `TEST12` pre-filled | Browser check |
| E17 | No placeholder `assetlinks.json` generated | Local checkout | **Pass** — only `.well-known/assetlinks.json.template` present; script removes any existing `assetlinks.json` when no fingerprint is supplied | File listing + script |
| E18 | Voice instrumentation presence | Local checkout | **Implemented** — one `getUserMedia` call site inside `startRec()`; `vpMark/vpBegin/vpReport` write `window.__DSVoicePerf` and log `[DSVOICE]` stage names only | Source audit (grep) |
| E19 | Chat safety controls presence | Local checkout | **Implemented** — `esc()` escaping, validated structures, 80-char cap, 600 ms per-seat flood limit, 60-message log cap, last 8 voice payloads | Source audit |
| E20 | Typing indicator message flow presence | Local checkout | **Implemented** — `typing` handled in `hostData`/`clientData`, `notifyTyping` 1.5 s throttle + 2.6 s auto-hide | Source audit |
| E21 | Debug APK built | Local checkout | **Pass** — built, but 187 MB and too large for emulator storage | Flutter build output |
| E22 | Release APK built | Local checkout | **Pass** — `domino_shak_app/build/app/outputs/flutter-apk/app-release.apk` (~50 MB), signed with `DOMINO_UPLOAD_KEY_PROPERTIES` pointing outside the project | Flutter build output; no secrets in project |
| E23 | Release APK installed on emulator | Emulator `emulator-5554` | **Pass** after `pm trim-caches` freed space | `adb install` output |

### 3.1 Public-host deployment evidence (real browser, 2026-11-19)

| # | Test | Environment | Result | Evidence |
|---|---|---|---|---|
| H1 | Explicit FTPS connection with verified certificate | `ftpupload.net:21` via `tools/ftps_deploy.py` | **Pass** — `TLSv1.3`, `CN=ftpupload.net`, cert verified; credentials entered by maintainer in hidden local prompt | Tool output; no credential value handled by agent |
| H2 | Pre-deploy backup | Remote `/liardominoes.gt.tc/htdocs` | **Pass** — 23 files to `deployment_backups/20261119-162401`, incl. original `index.html` (`d9d711ea…`) | Backup manifest |
| H3 | Staging upload and verification | `https://liardominoes.gt.tc/_staging/` | **Pass** — 22 files; new build rendered, mode selector present, `typeof Peer === 'function'`, `?room=TEST12` prefilled, 0 console errors | Real browser |
| H4 | Promotion to live root | `/liardominoes.gt.tc/htdocs` | **Pass** — 22 managed files copied, no remote deletions | Tool output |
| H5 | Rollback path exercised | Same host | **Pass** — 23 files restored; confirmed the rollback works, but it reverted the live `index.html` to the original build | Tool output + browser check showing old build |
| H6 | Second backup after the accidental revert | Same host | **Pass** — 44 files to `deployment_backups/20261119-163831` | Backup manifest |
| H7 | Re-promotion to live root | Same host | **Pass** — 22 managed files copied; no rollback afterwards | Tool output |
| H8 | Final live home page | `https://liardominoes.gt.tc/` | **Pass** — new build served; mode selector present, `typeof Peer === 'function'`, 0 console errors, 0 failed resources | Real browser |
| H9 | Live invitation URL | `https://liardominoes.gt.tc/?room=TEST12` | **Pass** — code `TEST12` prefilled, invite banner shown | Real browser |
| H10 | Live privacy page | `https://liardominoes.gt.tc/PRIVACY_POLICY.html` | **Pass** — bilingual policy page loaded | Real browser |

---

## 4. Physical-device evidence (kept separate from emulator)

| # | Test | Device / environment | Result | Evidence / caveat |
|---|---|---|---|---|
| P1 | Microphone routing fix diagnostic | Physical device `R9KY9045TRB`, diagnostic build (earlier phase) | **Pass with limitation** — `DSMIC diag: OK tracks=1` | One physical device, **diagnostic build**, not the final release build |
| P2 | Final no-diagnostic APK installed | Physical device `R9KY9045TRB` (earlier phase) | **Pass with limitation** — both permissions granted, no startup errors | Installation/startup check only; **not** audible capture proof |

**No other physical-device tests were run in this phase.** In particular, no second physical device was attached, so there is no real two-device gameplay, LAN, or voice result.

---

## 5. Not tested / blocked (explicitly not claimed)

| Item | Status | Why |
|---|---|---|
| Two real phones on a hotspot with no internet | **Not tested** | No physical devices attached; AP/client isolation risk not evaluated |
| Final-APK two-device audible voice capture and playback | **Not tested** | Requires two physical devices; no M1–M10 timing values measured (`VOICE_RECORDING_PERFORMANCE.md`) |
| Real two-device LAN gameplay (chat/voice/reconnect/host migration, 3–5 players) | **Not tested** | Emulator smoke only; `10.0.2.16` is NAT, not a LAN address |
| No PeerJS Cloud / STUN traffic during LAN mode | **Not tested** | No network capture / firewall rule run |
| Online Android↔Web gameplay (both host directions) | **Not tested** | Highest-priority cross-platform gap; PeerJS path unchanged this phase |
| Online Web↔Web gameplay on the current/deployed build | **Not tested** | Deployed build verified statically in a browser; no two-client game played |
| Invitation deep link from a real external app into a joined table | **Not tested** | Emulator `am start`-style prefill only; not a verified App Link |
| Verified Android App Links | **Blocked by hosting / Requires approval or external config** | No Play App Signing fingerprint; `/.well-known/` behind JS cookie challenge; no real `assetlinks.json` generated (template only) |
| FTPS upload of `domino_shak_web/` | **Done** | Maintainer entered credentials via the hidden local prompt; backup, staging, verification and promotion completed (H1–H10) |
| Backup / staging / rollback on the host | **Tested successfully** | Both backups, staging promotion and the rollback path were exercised (H2–H7) |
| Play AAB upload / publish | **Not performed** | Not authorized; only a release APK was built locally |
| Report reaching a reviewer / moderation backend | **Requires approval or external config** | Local-only report/block; no backend |

---

## 6. Build and regression notes

- `flutter analyze`: clean. `flutter test`: 12/12 pass (including 2 new LAN relay tests and 2 invitation URL/parse tests).
- Debug APK (~187 MB) exceeded emulator storage; `pm trim-caches` was required before installing the release APK.
- Release APK (~50 MB) was built with `DOMINO_UPLOAD_KEY_PROPERTIES` pointing **outside** the project. No credentials or fingerprints were printed or committed.
- The historical root `index.html` hash is unchanged: `d9d711ea1601785d89fb1b94845537c330ff95aa6bb412eafd3d95115d4b3e4f`.
- The bundled source hash changed in this phase; re-verify with `sha256sum` rather than relying on the older Phase 0 value (`a9a1f0c6…`). Observed 2026-11-19: `ab7c610e7b494d17bab825668f5081421ac30d7497e0e53f7a09c34f67a60d22`.
- No AAB upload and no Play publish. The static web build **was** deployed through verified explicit FTPS using the hidden local credential prompt; backup, staging, verification and promotion are recorded in §3.1. No hosting settings, DNS or domain were changed.

---

## 7. Related documents

- `LAN_MULTIPLAYER_ARCHITECTURE.md` — LAN design, implemented components, limits.
- `NETWORK_COMPATIBILITY_MATRIX.md` — status by device pair and mode.
- `APP_LINKS_SETUP.md` — deep-link implementation, Asset Links template, blockers.
- `WEB_DEPLOYMENT_GUIDE.md` — generated web project, corrected paths, upload checklist.
- `VOICE_RECORDING_PERFORMANCE.md` — instrumentation and pending measurements.
- `CHAT_IMPROVEMENT_PROPOSALS.md` — implemented chat controls and remaining proposals.
- `domino_shak_app/PRIVACY_AND_DATA_SAFETY.md` and `domino_shak_app/DATA_SAFETY_SUBMISSION.md` — data paths and disclosure drafts.
