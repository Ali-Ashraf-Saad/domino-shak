# Network compatibility matrix — Domino Shak

**Date:** 2026-11-19  
**Status:** documentation only for this file. No network code, STUN/TURN configuration, signalling service, or hosting setting was changed while writing it. The implementation it describes was completed in this phase (see `PHASE5_FEATURE_REPORT.md`).

---

## 1. How to read this matrix

Status values used below:

- **Tested successfully** — a recorded passing test exists for that pair and mode; evidence is named.
- **Tested with limitations** — partial evidence only (unit-only, one device, emulator only, or emulator NAT address), not the full target scenario.
- **Implemented (not gameplay-tested)** — the code path exists and is believed compatible, but no end-to-end gameplay test for that exact pair/mode was run in this phase.
- **Not tested** — no recorded test exists.
- **Unsupported / Blocked by design** — the design cannot serve that pair; a required component cannot exist in that environment.
- **Blocked by hosting** — requires a host configuration outside our control.
- **Requires approval or external config** — needs credentials, a signing fingerprint, or a decision.

Scope: Android app (`com.dominoshak.domino_shak`, bundled WebView game) and the website at `https://liardominoes.gt.tc/`. iOS is out of scope.

---

## 2. Current network architecture

### Online mode (unchanged this phase)

- Signalling: **PeerJS 1.5.4** cloud broker, effectively `wss://0.peerjs.com:443`.
- ICE: two public STUN servers only:
  - `stun:stun.l.google.com:19302`
  - `stun:global.stun.twilio.com:3478`
- **TURN: not configured** (existing recorded decision). No relay fallback.
- Game traffic: WebRTC peer-to-peer data channels; the host player is authoritative.
- App loads bundled `vendor/peerjs.min.js` and local fonts from `http://localhost:8080`.
- No developer-run signalling server and no PHP endpoint for gameplay.
- PeerJS/WebRTC signalling processes peer metadata and relays game, chat, and voice payloads via `0.peerjs.com`; see `domino_shak_app/PRIVACY_AND_DATA_SAFETY.md`.

### Offline LAN mode (implemented this phase)

- `lib/lan_service.dart`: Dart TCP relay on port `8974`, newline-delimited JSON envelopes (`register`, `registered`, `relay`, `peerleft`, `error`). No PeerJS Cloud, STUN, or internet dependency.
- `lib/web_shell.dart` + `lib/bridge.dart`: token-guarded `lanHost`, `lanConnect`, `lanSend`, `lanClose`, `lanStopHost`, `lanGetIp`; `dsLanMessage` / `dsLanPeerLeft` events into the WebView. `window.dsLan` exists only inside the Android WebView.
- `assets/web/index.html`: mode selector (online / LAN / bots), `LanPeer`/`LanConn` PeerJS-compatible shim, host IP + room code joining, LAN-only lobby.
- Full detail and limits: `LAN_MULTIPLAYER_ARCHITECTURE.md`.

---

## 3. Compatibility matrix

| Mode | Device pair | Status | Evidence / notes |
|---|---|---|---|
| **Online** | **Android ↔ Android** | **Implemented (earlier gameplay tests; not re-run this phase)** | Earlier emulator/device reports (`PHASE4_REPORT.md`, `REAL_DEVICE_TEST_REPORT.md`) recorded two-player sync, chat both directions, reconnect, host migration. PeerJS path unchanged this phase; not re-tested here. |
| **Online** | **Web ↔ Web** | **Implemented (not gameplay-tested this phase)** | Prior bundled-copy browser-peer tests exist (`PROJECT_AUDIT_AND_NEXT_STEPS.md §B`). No gameplay test on the current build or public host this phase. |
| **Online** | **Android ↔ Web** | **Implemented (not gameplay-tested)** | Both use the same room-code model, PeerJS 1.5.4 and compatible core message families. No recorded explicit web ↔ Android gameplay test. Highest-priority gap. |
| **Offline LAN** | **Android ↔ Android** | **Transport: Tested with limitations; gameplay: Not tested** | `flutter test` 12/12 incl. 2 relay unit tests; single-device emulator smoke created a local room and showed IP + code (`10.0.2.16`, `3CWHV`). Two real phones with no internet: **Not tested**. |
| **Offline LAN** | **Web ↔ Web** | **Unsupported / Blocked by design** | Browser cannot host the Dart TCP relay; static host cannot run a custom server; no secure-context browser TCP server. |
| **Offline LAN** | **Android ↔ Web** | **Unsupported / Blocked by design** | Hosted browser has no `window.dsLan` (Android WebView only) and cannot be the LAN host. |

Additional cross-cutting conditions:

| Condition | Status | Effect |
|---|---|---|
| Restrictive / symmetric NAT, no TURN | **Blocked for those networks** | Direct WebRTC path may fail; no relay exists. Recorded decision: no TURN for now. |
| Mobile data vs Wi-Fi with no internet | **Online blocked; LAN requires same-LAN devices** | Online mode needs the public broker; LAN needs devices on one local network with no AP isolation. |
| Hotspot with AP/client isolation enabled | **Blocked for testing** | Can invalidate LAN tests even when code is correct; must be disabled or avoided. |
| Host-side JavaScript challenge | **Blocked by hosting (App Links only)** | Does not affect WebRTC gameplay, but blocks direct `assetlinks.json` serving (see `APP_LINKS_SETUP.md`). |
| UGC moderation backend | **Requires approval / external config** | Does not affect connectivity, but remains a release blocker (local report/block only). |

---

## 4. Detailed status by pair

### 4.1 Android ↔ Android (online) — implemented, earlier gameplay evidence

- Earlier emulator/device reports cover two-player play, chat, reconnect, and host migration in both directions.
- The online path was not changed in this phase; these results were not re-run.
- Final-APK two-device voice retest is still **Not tested** (`VOICE_RECORDING_PERFORMANCE.md`).

### 4.2 Web ↔ Web (online) — implemented, not gameplay-tested this phase

- Prior browser-peer tests used the bundled copy and covered room creation, join, sync, chat, reconnect, and host migration.
- No full two-browser game test was run on the public host or with the current build.
- The deployable `domino_shak_web/` was generated and tested locally, then deployed to the public host on 2026-11-19 and statically verified there (mode selector, PeerJS loaded, `?room=TEST12` prefill, no console errors, no failed resources). No full two-browser game was played on the live host. See `WEB_DEPLOYMENT_GUIDE.md`.

### 4.3 Android ↔ Web (online) — implemented, not gameplay-tested

This is the highest-priority missing cross-platform check.

Required test before claiming support:

1. Open `https://liardominoes.gt.tc/?room=CODE` in a browser and create/join a room.
2. Join the same room from the Android app using the code.
3. Verify: state sync, chat both directions, voice send/receive, disconnect/reconnect, seat restoration, and host migration in both directions.
4. Repeat with the web player as host and with the Android player as host.
5. Record device, browser, app build, and result.

Known compatibility risks:

- extra UGC fields in bundled messages appear additive but are untested across versions;
- native sharing now sends a full invitation URL while the web game builds `?room=CODE`;
- bundled vs historical CDN PeerJS loading path (the deployed build uses bundled PeerJS 1.5.4).

### 4.4 Offline LAN — Android ↔ Android: transport tested with limitations

- `LanService` relay routes messages between two simulated clients in a unit test and reports an unknown peer without crashing.
- On emulator `emulator-5554`, LAN mode was selected, a local room was created, and the lobby showed `طاولة محلية — ... IP: 10.0.2.16 والكود 3CWHV`. `10.0.2.16` is the emulator NAT address, not evidence of a LAN address.
- **No real two-phone hotspot test** (no physical devices attached). AP/client isolation remains an untested risk.
- No network-capture confirmation that LAN mode emits no PeerJS Cloud / STUN traffic.

### 4.5 Offline LAN — Web pairs: unsupported by design

- A static hosted browser page cannot run a TCP signalling server.
- A browser cannot open a raw TCP server in a secure context; the Dart relay only runs inside the Android app.
- `window.dsLan` is defined only in the Android WebView; a hosted browser shows an "Android only" toast in LAN mode.
- Do not treat these pairs as planned work; they are out of scope for this design.

---

## 5. Test checklist

- [x] `flutter analyze` clean; `flutter test` 12/12 pass.
- [x] LAN relay two-client register + relay unit test.
- [x] LAN relay unknown-peer no-crash unit test.
- [x] LAN single-device emulator smoke (mode select, local room, lobby IP + code).
- [x] Invitation URL/parse unit tests (public host, HTTPS-only, code validation).
- [x] Emulator cold start with `https://liardominoes.gt.tc/?room=COLD77` → prefilled code + invite banner.
- [x] Emulator warm start with `WARM88` → prefilled code.
- [x] Local web server `?room=TEST12` prefill (browser, `python3 -m http.server 8765`).
- [ ] Android ↔ Android online: full game, chat, voice, reconnect, host migration **on the current build**.
- [ ] Web ↔ Web online on a deployed build: full game, chat, voice, reconnect, host migration.
- [ ] Android ↔ Web online: both host directions, full checklist in §4.3.
- [ ] Two real devices on a hotspot with AP/client isolation off, no internet.
- [ ] No public STUN / PeerJS Cloud traffic during LAN mode (network capture or firewall rule).
- [ ] Final APK voice capture on two real devices.
- [ ] App Link verification (`assetlinks.json` with Play App Signing fingerprint + hosting exemption) — **Blocked by hosting**.

---

## 6. Limitations and blockers

- Online cross-platform play is code-compatible but unproven this phase; do not market it as tested.
- Offline LAN is Android↔Android only, with two-device offline play **Not tested**.
- No TURN: online connectivity is not guaranteed on all networks (accepted decision).
- Verified App Links are blocked by the missing Play App Signing fingerprint and the hosting challenge.
- The web project was generated, locally tested, then deployed to the public host via verified explicit FTPS (credentials entered by the maintainer in a hidden local prompt) and statically verified there. Cross-platform gameplay is still untested.
- No Play upload or publish was performed; debug/release APKs are not release evidence.
- Moderation is still local-only and is a separate release blocker.

---

## 7. Related documents

- `LAN_MULTIPLAYER_ARCHITECTURE.md` — implemented LAN transport and its limits.
- `PHASE5_FEATURE_REPORT.md` — consolidated per-test evidence.
- `WEB_DEPLOYMENT_GUIDE.md` — public host and deployment checklist.
- `APP_LINKS_SETUP.md` — deep-link implementation and hosting-challenge blockers.
- `VOICE_RECORDING_PERFORMANCE.md` — voice instrumentation and pending measurements.
- `CHAT_IMPROVEMENT_PROPOSALS.md` — implemented chat controls and remaining proposals.
- `PROJECT_AUDIT_AND_NEXT_STEPS.md` — Phase 0 evidence.
