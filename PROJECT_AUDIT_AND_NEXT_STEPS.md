# Domino Shak — Phase 0 Project Audit and Next Steps

**Date:** 2026-11-19  
**Phase:** 0 — read-only audit  
**Scope:** current local project, Android app source, documentation, privacy/developer configuration, public website and observable hosting behaviour.

> This report is the only file created during Phase 0. No source, hosting, production file, package, upload, deployment, or live-site change was made.

> **Current status (2026-11-19, added after Phase 0):** This document is a **Phase 0 snapshot**. Section 5 ("Current live website status") records the host as it was *during the audit* — the original build. It is now **superseded**: the Phase 1+ web build was deployed to `https://liardominoes.gt.tc/` and statically verified the same day. For the current state, see `WEB_DEPLOYMENT_GUIDE.md` and the public-host evidence in `PHASE5_FEATURE_REPORT.md` §3.1. Verified App Links remain blocked.

---

## 1. Current architecture

### 1.1 Application shape

Domino Shak is currently a **Flutter Android shell around a bundled web game**:

1. Flutter starts an `InAppLocalhostServer` on `http://localhost:8080`.
2. An Android `InAppWebView` loads `http://localhost:8080/index.html`.
3. The game is a single large HTML/CSS/JavaScript file served from the app bundle.
4. A narrow, token-gated JavaScript ↔ Dart bridge exposes only:
   - `shareRoom(code)`
   - `copyCode(code)`
   - `requestMic()`
   - native toast/back/leave helpers
5. PeerJS is used for signalling and WebRTC data connections.
6. The host player is authoritative for game state; guests receive state snapshots and send actions to the host.

### 1.2 Networking

- Signalling: PeerJS default cloud broker, effectively `wss://0.peerjs.com:443`.
- ICE: two public STUN servers only:
  - `stun:stun.l.google.com:19302`
  - `stun:global.stun.twilio.com:3478`
- TURN: **not configured** (existing recorded decision).
- Game traffic is peer-to-peer WebRTC data channels; no game server is required.
- The app does not use `file://`; the trusted origin is always `http://localhost:8080`.

### 1.3 Source state at audit time

- Git branch: `main`
- `HEAD`: `01be6c1ccfd2e60b36aaf9f80b70a45b2a15f965` — “Fix WebView microphone capture on Android”
- Working tree: clean
- Current source includes `android.permission.MODIFY_AUDIO_SETTINGS`.
- The tracked signed AAB is older than this fix and does **not** contain `MODIFY_AUDIO_SETTINGS`; it is also stale relative to the updated icon. Any future release must rebuild it from current source.

---

## 2. Current implemented features

### 2.1 Android shell / platform

| Feature | Status | Notes |
|---|---|---|
| Flutter WebView shell | Implemented | `lib/web_shell.dart`, `lib/main.dart` |
| Localhost server | Implemented | Serves `assets/web` on `127.0.0.1:8080` |
| Navigation allow-list | Implemented | Only localhost stays in WebView; external links go to Android launcher |
| JavaScript bridge | Implemented | Per-launch random token; room-code validation |
| Runtime microphone permission flow | Implemented | Prompt only from explicit mic action |
| WebView microphone permission grant | Implemented | Granted only for localhost and only after Android permission is granted |
| Android back/leave handling | Implemented | Routes through WebView helpers and game confirmation flows |
| App lifecycle handling | Partial | Resume re-notifies page; local server closes on detach/dispose with no restart path |
| External deep links / Android App Links | Missing | No activity intent filter, no `autoVerify`, no `MainActivity.onNewIntent`, no link-handling dependency |
| Signing configuration | Implemented | Upload key from external properties file; no secrets in repository |
| Play assets | Draft, not submitted | Listings, screenshots, policy, data-safety drafts exist; nothing uploaded |

### 2.2 Game / web implementation

| Feature | Status | Notes |
|---|---|---|
| Room creation and joining | Implemented | 4–8 character code, 2–5 players, host seat 0 |
| Invitation URL parsing | Implemented internally | `?room=CODE` pre-fills the join field |
| Invitation sharing on Android | Partial | Native share/copy sends only the room code; HTML still contains localhost URL logic that the mobile shim overrides |
| PeerJS / WebRTC | Implemented | PeerJS 1.5.4; cloud broker; STUN only |
| Reconnection | Implemented | Tokens, heartbeat, reconnect probes, seat/hand restoration |
| Host migration | Implemented | Snapshot-based successor promotion with epoch-based peer IDs |
| Chat | Implemented | Text, quick phrases, emoji, unread badge, voice bubbles |
| Voice recording | Implemented | `getUserMedia` + `MediaRecorder`, 30 s cap, data URL payload |
| Voice playback | Implemented | Audio element, progress UI, autoplay queue |
| Settings | Implemented | Sound, volume, haptics, reduced motion, wake lock |
| UGC safety controls in bundled app | Implemented locally | Terms gate, anonymous PID, local report outbox, block/filter |
| Real reviewer/back-end moderation | Missing | Reports never leave the device |
| Offline LAN signalling | Missing | No local broker/discovery; online signalling is required today |

---

## 3. Verified features and evidence

### 3.1 Independently verified in this audit

- **Live HTML identity:** the raw HTML served at `https://liardominoes.gt.tc/` hashes to:

  `d9d711ea1601785d89fb1b94845537c330ff95aa6bb412eafd3d95115d4b3e4f`

  This is byte-identical to `/home/ali/Documents/DominoGame/index.html`.

- **Live invitation parameter:** opening `https://liardominoes.gt.tc/?room=TEST12` correctly pre-filled `TEST12`, showed the invitation banner, hid create-room/bots, and highlighted Join.
- **Live browser rendering:** the page rendered the Arabic home screen in a desktop browser with no console errors.
- **Live external dependencies loaded successfully:** PeerJS CDN script, Google Fonts CSS, and font files all returned HTTP 200.
- **HTTPS:** valid certificate for `CN=gt.tc`, issued by ZeroSSL ECC DV SSL CA 2, `Verify return code: 0 (ok)`. Server header: `openresty`.
- **Challenge behaviour:** plain `curl` is stopped by a JavaScript cookie challenge; a real browser executes the challenge and loads `?i=1`.
- **`.well-known/assetlinks.json`:** currently absent. A direct request receives the JavaScript challenge first; after the browser cookie is set, the path resolves to an InfinityFree 404 page. No App Links asset file is deployed.
- **No PHP endpoint observed or required for current core gameplay.**

### 3.2 Evidence from existing project reports

These were not re-run in Phase 0; they are recorded in the repository.

- `flutter analyze`: clean.
- `flutter test`: 7/7 passed.
- Emulator and real-device tests recorded in `PHASE4_REPORT.md` and `REAL_DEVICE_TEST_REPORT.md` include:
  - cold launch, RTL UI, room creation, code sharing, back handling;
  - two-player sync, chat both directions, disconnect/reconnect;
  - host migration in both directions;
  - token-based seat restoration;
  - synthetic WebAudio voice send/receive/playback.
- Voice **real microphone capture originally failed** with `NotReadableError` on test devices; this was a device/WebView audio-routing issue.
- After adding `MODIFY_AUDIO_SETTINGS`, a diagnostic build on real device `R9KY9045TRB` reported:

  `DSMIC diag: OK tracks=1`

  The temporary diagnostic code was removed; the final APK was rebuilt and installed on that device with both permissions granted and no startup errors. The second device was not connected when requested.
- Existing evidence does **not** prove:
  - real audible voice capture on both devices with the final no-diagnostic APK;
  - web ↔ Android real-device play;
  - cross-network or restrictive-NAT connectivity;
  - offline LAN play;
  - real moderation intake.

---

## 4. Existing developer and privacy configuration

### 4.1 Confirmed real values — preserve exactly

| Item | Current value / location |
|---|---|
| Developer/app name | `Domino Shak` / `دومينو شك` |
| Support email | `dominoshak.support@gmail.com` |
| Privacy policy URL | `https://ali-ashraf-saad.github.io/dominoshak-privacy/` |
| Privacy repository | `https://github.com/Ali-Ashraf-Saad/dominoshak-privacy` |
| Privacy repo treatment | Separate repo; must not be modified in this work |
| In-app policy | `http://localhost:8080/PRIVACY_POLICY.html` in the bundled app |
| Main app repository | `https://github.com/Ali-Ashraf-Saad/domino-shak`, private |
| Public game site | `https://liardominoes.gt.tc/` |
| Final application ID | `com.dominoshak.domino_shak` |
| Signing strategy | Play App Signing selected; upload key outside project; no secret committed |

### 4.2 Documentation caveats

- There is **no root `README.md`**, no `PHASE5_REPORT.md`, and no `GOOGLE_PLAY_RELEASE_REPORT.md`.
- Some older documents still contain placeholders or early-release wording (“contact to be filled”, “no AAB”, “signing pending”). Later release documents and actual configuration supersede those older statements.
- No separate official developer/product website is configured in the store drafts. The existing `liardominoes.gt.tc` domain is the known public game host.
- No passwords, private keys, signing credentials, or tokens are reproduced in this report.

---

## 5. Current live website status (as observed during Phase 0 — now superseded)

> The state below reflects the audit snapshot only. The live host now serves the deployed Phase 1+ build; see the note at the top of this document.

- URL: `https://liardominoes.gt.tc/`
- Deployed file: byte-identical to the original project `index.html`.
- Deployed version: the **original web game**, not the modified bundled app copy.
- PeerJS: loaded from `https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js`.
- Fonts: loaded from Google Fonts.
- Invitation format: `https://liardominoes.gt.tc/?room=CODE`.
- Join behaviour: invitation code is sanitized to uppercase alphanumerics, max 8 characters, then pre-filled into the join field.
- Room creation/joining/protocol: same core protocol family as the app.
- Desktop browser: loaded and rendered successfully during this audit.
- Mobile browser: not directly exercised in this audit because no device was attached; responsive CSS exists, and the bundled app copy previously passed small-viewport tests at 720×1280 and 540×960.
- Console: no errors observed on load or invitation-parameter load.
- Live hosting identity: InfinityFree-style 404/error pages and `openresty`.

---

## 6. Hosting capabilities and restrictions

### 6.1 Observable facts

- HTTPS is available and the certificate validates.
- Static HTML/CSS/JS is served successfully.
- External CDN scripts/fonts are allowed by the browser.
- The site is behind a JavaScript cookie challenge. This blocks plain HTTP clients and would likely block automated verifiers that do not execute JavaScript.
- `/.well-known/assetlinks.json` is not present. A request is challenged first; with the challenge cookie, the path reaches an InfinityFree 404 page.
- No robots.txt or privacy page is deployed on the game domain.

### 6.2 Not verifiable read-only

- FTP/FTPS availability and credentials.
- Exact document root path.
- Account-specific file-size, disk, bandwidth, or upload limits.
- Whether the hosting control panel can exempt `/.well-known/` from the JavaScript challenge.
- Whether a newly uploaded dot-directory would be served with the correct `application/json` content type.

### 6.3 PHP endpoint necessity

None of A–D requires a PHP endpoint:

- App Links needs a static `assetlinks.json` file.
- Web fallback and room URLs are static HTML with query parameters.
- Multiplayer already uses PeerJS cloud signalling and WebRTC.
- Voice/chat changes are client-side.
- Offline LAN must not rely on public hosting at all.

A PHP endpoint would only be needed for a future moderation/review backend or a custom always-online signalling service, neither of which is part of A–D as stated.

---

## 7. Differences between local and deployed website versions

The phrase “local website” must be split into two files:

| File | SHA-256 | Role |
|---|---|---|
| `/home/ali/Documents/DominoGame/index.html` | `d9d711ea...d4b3e4f` | Original website; currently matches live site |
| `domino_shak_app/assets/web/index.html` | `a9a1f0c6...c85b48` | Bundled game used by Android app |

The live site matches the **original**, not the bundled app copy.

Main bundled-app differences:

- PeerJS and fonts are bundled locally instead of CDN-loaded.
- Mobile shim adds native back/share/copy/mic integration.
- Native sharing sends a **room code**, not a localhost URL.
- UGC community terms gate.
- Anonymous PID and local report/block controls.
- In-app privacy policy page and links.
- Android-specific UI relabelling.

Core game rules, room joining, reconnect, host migration and chat/voice message payloads remain broadly the same protocol family. The bundled copy adds extra fields such as `pid`/`pids` to some messages; these appear additive, but cross-version behaviour has not been formally tested.

---

## 8. Missing features

1. Android App Links / external deep links.
2. Deployed `.well-known/assetlinks.json`.
3. Verified production App Links certificate fingerprint (depends on Play App Signing enrollment).
4. Universal invite flow that opens the app when installed and the website otherwise.
5. Tested web ↔ Android multiplayer.
6. Web safety/privacy parity with the app if required.
7. Real microphone verification on both devices with the final APK.
8. Updated signed AAB built from current source (icon + microphone fix).
9. TURN or equivalent relay for restrictive networks (currently a recorded “no TURN” decision).
10. Offline LAN signalling with no cloud broker or public STUN.
11. Real UGC moderation intake/reviewer/appeal process.
12. Completed content-rating questionnaire and final Play submission readiness.

---

## 9. Technical feasibility of each requested improvement

### A. Smart Room Invitations

**Status: PARTIAL — hosting-dependent and decision-dependent.**

Already supported:

- Web URL format `?room=CODE` works on the live site.
- Internal WebView prefill works on cold page load.
- Room codes are already validated and shared natively on Android.

Missing:

- No Android `VIEW`/`BROWSABLE` intent filter.
- No `autoVerify`.
- No `MainActivity.onNewIntent` or initial-link handling.
- No assetlinks file.
- No tested cold/warm external start into a joined table.

Feasible approach:

1. Keep `https://liardominoes.gt.tc/?room=CODE` as the universal URL.
2. Add Android intent-filter handling and pass the code safely into the WebView.
3. Handle both cold start and warm start.
4. Publish a valid `/.well-known/assetlinks.json` using the **Play app-signing certificate fingerprint**.
5. Ensure the file is served directly as JSON, without the JavaScript challenge.

Key risk: the current hosting challenge likely prevents Google’s verifier from reading `assetlinks.json`. This must be confirmed and resolved; no hosting change was made in Phase 0.

**No PHP needed.**

---

### B. Web and Android Cross-Platform Multiplayer

**Status: PARTIAL — technically feasible, unverified end-to-end.**

Already supported:

- Both versions use the same room-code model and PeerJS 1.5.4.
- Both use the same WebRTC signalling style and core message protocol.
- Web ↔ web was exercised with browser peers in prior bundled-copy testing.
- Android ↔ Android was exercised on emulator/phone in prior reports.

Gaps:

- Web ↔ Android was not specifically verified.
- Live web uses CDN PeerJS; app uses bundled PeerJS 1.5.4 — same version, different loading path.
- Bundled app adds UGC fields and gates that the original site does not have. Core gameplay should remain compatible, but moderation controls will not work fully across versions.
- Invitation UX differs: web shares a URL; app shares a code.

Recommendation: treat universal `?room=CODE` links from A as the entry point, then run explicit web ↔ Android tests for create/join, chat, voice, reconnect and host migration.

**No PHP needed.**

---

### C. Voice and Chat

**Status: PARTIAL — feasible; small remaining verification/polish work.**

Already supported or improved:

- Microphone is accessed only after the user taps the voice button.
- Manifest now declares `RECORD_AUDIO` and `MODIFY_AUDIO_SETTINGS`.
- WebView permission is granted only for localhost after Android permission is granted.
- Recording stops tracks after each message.
- Chat and voice payloads are compatible with the existing protocol.
- Synthetic voice send/receive/playback was tested previously.
- The real-capture failure on `R9KY9045TRB` was diagnosed and fixed; diagnostic capture returned `OK tracks=1` after adding `MODIFY_AUDIO_SETTINGS`.

Remaining work:

- Retest the final no-diagnostic APK through the actual UI on both devices.
- Measure/reduce perceived tap-to-record delay without pre-opening the microphone at app start.
- Confirm playback and chat UX after the final build.
- Reconcile one existing evidence note where playback-class state differed between the two directions.

**No PHP needed.**

---

### D. Offline LAN Multiplayer

**Status: MISSING — technically feasible but the largest change.**

Current blocker: the app depends on PeerJS cloud signalling and public STUN. With no internet, room creation/joining cannot complete.

Required work:

- Independent local signalling on the Android device/local network.
- Local device discovery or known-peer connection method.
- WebRTC ICE using local/host candidates only; no public STUN requirement.
- A clear online/offline mode selection or automatic fallback.
- Preserve the existing online mode unchanged.
- Test two devices on a real hotspot; earlier attempts were affected by AP/client isolation.

Reasonable approach: add a small native Android LAN signaling module (NSD/mDNS or UDP discovery plus a local WebSocket/HTTP endpoint) and expose only a minimal bridge to the bundled WebView game. This stays consistent with the existing “thin native bridge” architecture but is more native work than A–C.

Wi-Fi Direct is an alternative but changes connectivity assumptions and is not the same as a normal hotspot network.

**No public hosting or PHP needed; by definition this mode must work without them.**

---

## 10. Risks and dependencies

| Risk / dependency | Impact |
|---|---|
| Play App Signing certificate not available until enrollment | Production `assetlinks.json` fingerprint cannot be finalized yet |
| JavaScript challenge on hosting | May block App Links verification; must be exempted for `.well-known/` |
| `.well-known/assetlinks.json` currently missing | Verified App Links cannot work today |
| Stale AAB | Current signed artifact lacks icon/microphone fix |
| Second Android device unavailable | Real mic fix verified on one device only |
| PeerJS cloud dependency | Offline mode impossible without local signaling; online mode depends on third-party broker |
| STUN-only configuration | Restrictive NAT/cross-network connections may fail; existing no-TURN decision accepted for now |
| AP/client isolation | Can invalidate hotspot tests even when code is correct |
| Web/app version differences | Safety/privacy UX differs; cross-version moderation indicators may be incomplete |
| UGC moderation missing | Play release blocker independent of A–D |
| Content rating incomplete | Play submission cannot be finalized |
| Local server lifecycle | No restart path if detached/disposed without process death |
| Non-cryptographic room/token randomness in JS | Low immediate impact, but inconsistent with the secure bridge token |

---

## 11. Recommended implementation order

No implementation has started. The developer decisions are now recorded in section 12. Recommended order:

1. **Confirm remaining hosting facts:** direct JSON serving for `/.well-known/`, document root and upload limits; do not assume verified App Links.
2. **Rebuild and re-verify the signed release artifact** from current source so icon and microphone fixes are included.
3. **Smart invitations foundation:** universal `?room=CODE` URL, Android cold/warm link handling, safe code injection into the WebView.
4. **Hosting enablement:** publish static `assetlinks.json` only after the correct Play signing fingerprint and direct JSON serving are confirmed.
5. **Voice/chat verification:** retest final APK microphone capture on both devices; apply small UX/latency improvements without violating explicit-action access.
6. **Web parity and cross-platform verification:** bring the hosted site to app-level safety/privacy parity, then test web ↔ Android create/join, chat, voice, reconnect and host migration.
7. **Offline LAN:** separate phase with native local signalling, hotspot testing, and online-mode regression tests.
8. **Play release blockers:** moderation intake, content rating, Data Safety final verification, Play enrollment/upload.

---

## 12. Questions requiring developer decisions

All five decisions below were answered by the developer on 2026-11-19. They are recorded here so Phase 1 can start from agreed scope without re-asking.

### 1. Public host for App Links and web fallback

**Decision:** Use `https://liardominoes.gt.tc/` as the permanent public web fallback and Android App Links host.

---

### 2. App Links timing with Play App Signing

**Decision:** Build deep-link handling now and complete verified App Links later, after the Play app-signing certificate becomes available. Until then, use non-verified deep links for testing only.

---

### 3. Web safety/privacy parity

**Decision:** Bring the public website to full safety/privacy parity with the bundled Android app: community terms, privacy links, local report controls and block controls.

---

### 4. Offline LAN implementation approach

**Decision:** Approve native Android LAN signalling for hotspot play, exposed to the web game through a minimal bridge. The existing online mode must be preserved.

---

### 5. Hosting challenge exemption

**Decision:** Treat `/.well-known/assetlinks.json` as blocked until direct JSON serving without the JavaScript challenge is confirmed. Verified App Links must not be assumed to work on the current challenge-protected host.

---

## End of Phase 0

This audit stops here. No Phase 1 implementation, hosting change, upload, or live-site modification has been performed.

---

## Phase 1 decisions applied (documentation note)

Added 2026-11-19 as a follow-up note; all Phase 0 content above is preserved unchanged.

The developer decisions in section 12 have been carried into six practical planning documents: `WEB_DEPLOYMENT_GUIDE.md`, `APP_LINKS_SETUP.md`, `CHAT_IMPROVEMENT_PROPOSALS.md`, `VOICE_RECORDING_PERFORMANCE.md`, `NETWORK_COMPATIBILITY_MATRIX.md`, and `LAN_MULTIPLAYER_ARCHITECTURE.md`. They record: `https://liardominoes.gt.tc/` as the web/App Links host; the historical `index.html` hash as immutable; the bundled web copy as the canonical implementation source; a generated `domino_shak_web/` project; App Links built now and verified later with the production Play signing fingerprint still unavailable; the hosting challenge treated as blocked for `/.well-known/`; full web safety/privacy parity; approved native Android LAN signalling (planned only); and no assumption of PHP/DB moderation support.

This was a documentation-only update. No source, generated web project, hosting, assetlinks file, build, AAB, upload, or Play Console action was created or changed. Deployment, verified App Links, moderation backend, final-APK two-device voice testing, and release readiness remain open blockers.
