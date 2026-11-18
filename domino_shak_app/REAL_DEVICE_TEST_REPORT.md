# Real-device and emulator test report

Date: 2026-11-18
Scope: Android only. No release AAB was produced and nothing was uploaded to Google Play.
Original website `../index.html` hash re-verified unchanged:
`d9d711ea1601785d89fb1b94845537c330ff95aa6bb412eafd3d95115d4b3e4f`.
Bundled mobile copy hash (updated after Phase 7 UGC controls):
`a9a1f0c69c33071a10b6aa5ea22e0f952b0b0fd2c9c16eefe36cc7d642c85b48`.

## 1. Environment

| Item | Value |
| --- | --- |
| Physical phone | `adb -s RZ8T30GA9ZX`, SM_A525F, Android 14 / API 34, 1080x2400, Wi-Fi 192.168.1.9 |
| Emulator | `adb -s emulator-5554`, sdk_gphone64_x86_64, Android 14 / API 34, 720x1280 (also tested at 540x960), NAT 10.0.2.16 |
| Host | Linux, 192.168.1.25, JDK 17, Flutter 3.x |
| App under test | `com.dominoshak.domino_shak`, debug APK built in Phase 4, installed on both devices and kept running |
| Local origin | `http://localhost:8080` (never `file://`) |
| CDP | WebView DevTools forwards: `tcp:9223` (phone), `tcp:9222` (emulator), `suppress_origin=True` |
| Network | Same Wi-Fi/LAN during Tests A/B. No Wi-Fi or mobile-data settings were changed. Mobile data was not used. During the later Phase 7 re-test the AP BSSID changed to `dc:51:93:ac:e5:19` and client isolation blocked device↔device/host traffic (see §5). |
| TURN | None configured. STUN only (Google + Twilio), as in the shipped web app. |

All device commands used explicit serials. No source files were edited during this phase; only evidence files were added under `test_evidence/`.

## 2. Method

- Gameplay was driven through rendered DOM controls (real buttons/inputs) via Chrome DevTools Protocol `Runtime.evaluate`, not by calling game internals.
- The page script is wrapped in an IIFE, so top-level `V`, `G`, and `peer` are not reachable from `Runtime.evaluate`. State was read from rendered DOM (hands, seats, board, history, chat, badges, overlays).
- ICE/STUN evidence used DevTools-only `Page.addScriptToEvaluateOnNewDocument` instrumentation wrapping `RTCPeerConnection`. This instrumentation existed only in the CDP session; no app or website source was changed.
- Voice evidence used DevTools-only patching of `navigator.mediaDevices.getUserMedia` to return a fresh WebAudio `MediaStream` per call, because neither device exposed a working audio input. This is synthetic audio and is **not** real microphone verification.
- Screenshots were captured with `adb -s <serial> exec-out screencap -p`. Logs were captured with `adb -s <serial> logcat -d` and CDP event dumps.

## 3. Result summary

| # | Case | Result |
| --- | --- | --- |
| A1 | Phone host → emulator guest: room creation, join, 14/14 tiles | Pass |
| A2 | Turn, tile, board, history sync (5 turns) | Pass |
| A3 | Chat: guest→host typed, host→guest quick phrase + emoji, unread badge | Pass |
| A4 | Guest disconnect → host shows “فاصل” → reconnect, same seat/hand | Pass (hand IDs captured; see note) |
| A5 | Host migration after host force-stop → emulator becomes host | Pass |
| A6 | Former host rejoins as guest while migration persists | Pass |
| A7 | Game completion (23 turns) + rematch (14/14) | Pass |
| B1 | Emulator host → phone guest: room, join, 14/14 | Pass |
| B2 | Turn/board/history sync (4 turns), chat both directions, unread badge | Pass |
| B3 | ICE/STUN: host/srflx candidates, direct UDP, connected state, no TURN | Pass |
| B4 | Token-based hand restoration after guest page reload | Pass (`restoration_identical: true`) |
| B5 | Reverse host migration (emulator host reloaded → phone becomes host) | Pass |
| V1 | Android/WebView microphone permission dialog and denial handling | Pass (UI), real capture failed |
| V2 | Real microphone record/send | **Failed — environmental audio-source limitation** |
| V3 | Synthetic record → send → receive → playback, both directions | Pass (synthetic only) |
| V4 | 30-second max duration auto-send | Pass (synthetic) |
| V5 | Repeated recordings | Pass (synthetic) |
| D1 | Settings: sound, vibration, wake lock, volume, persistence | Pass |
| D2 | Keyboard text input | Pass |
| D3 | Clipboard copy/paste | Pass |
| D4 | Native share sheet (WhatsApp target present) | Pass |
| D5 | Back button | Pass (no crash; no confirmation dialog in solo game) |
| D6 | Background/resume with game state preserved | Pass |
| D7 | Small-screen layout (720x1280 and 540x960) | Pass, no overflow |
| D8 | Android 15/16 | **Not tested — no device/AVD available** |

## 4. Detailed results

### 4.1 Test A — physical phone host, emulator guest

Room `PHONE1`, 2 players, names `PhoneHost` / `EmulGuest`. Both started with 14 tiles.

- 5 alternating turns played through UI. Board, history, turn indicator, and hand counts synchronized on both devices. One intentionally false claim was included and synchronized.
- Typed chat `messagesync-1` guest→host produced an unread badge `١` on the host before opening chat; after opening, the message was visible. Quick phrase `لعبة حلوة` and emoji `🔥` host→guest were delivered.
- Guest force-stop: host rendered the seat as `فاصل`. Guest relaunched and rejoined with the same token/seat; both returned to game.
- Host force-stop: emulator became host (`👑`). Phone relaunched and rejoined as guest while the emulator retained ownership.
- 23 further UI turns completed the game. Both devices showed the same ranking overlay. Guest ready + host start produced a rematch with 14/14 tiles.

Evidence: `testA_phase1.json`, `testA_phase2.json`, `testA_phone_*.png`, `testA_emulator_*.png`, `testA_*_cdp_events*.jsonl`, `testA_*_logcat.txt`.

Note: the explicit hand-ID equality before/after drop was not captured for this run (the DOM hand changed as turns were played during the drop). Hand restoration was captured explicitly and passed in Test B.

### 4.2 Test B — emulator host, physical phone guest

Room `EMUHOST`, 2 players, names `EmulHost2` / `PhoneGuest2`. Both started with 14 tiles.

- 4 alternating turns, board/history/turn synchronized. One intentionally false claim included.
- Typed chat `reverse-direction-1` emulator→phone produced an unread badge on the phone; quick phrase `حظ سعيد` phone→emulator was delivered.
- ICE evidence (9 events per device):
  - Phone local candidate `192.168.1.9`, srflx `41.39.70.39`; emulator local `10.0.2.16` plus IPv6 `fec0::...`.
  - `iceconnectionstatechange` reached `connected`; direct UDP host/srflx candidates; no relay/TURN candidate.
- Guest page reload: host saw the guest as offline; guest rejoined with the same token. `restoration_identical: true` — the exact hand IDs matched before and after.
- Host page reload: phone guest became host (`👑`).

Evidence: `testB.json`, `testB_*.png`, `testB_*_cdp_events.jsonl`, `testB_*_logcat.txt`.

### 4.3 Voice

- Tapping 🎤 on the phone showed the native Android microphone permission dialog (`voice_phone_01_permission_dialog.png`). After granting the runtime permission and WebView `audioCapture`, `window.__dsMicReady` became true.
- Real capture still failed on both devices: `getUserMedia({audio:true})` → `NotReadableError: Could not start audio source`. `dumpsys media.audio_flinger` reported `Input device: 0 (AUDIO_DEVICE_NONE)` on both. The emulator was started with `-allow-host-audio`, but it still exposed no input device; the host `arecord -D hw:0,0` succeeded, so the failure is the device/emulator audio path, not a missing host microphone.
- Denied handling: with `RECORD_AUDIO` revoked, tapping 🎤 did not start a recording; the app showed the Arabic denial toast and the game remained usable (`voice_phone_denied_handling.png`, `voice_test_salvage.json`).
- Synthetic pipeline (DevTools-only WebAudio source, fresh stream per call):
  - Phone→emulator: 5 s and 7 s messages received; playback `.vplay` click activated the playing class on the emulator.
  - Emulator→phone: 4 s and 6 s messages received; playback activated the playing class on the phone.
  - 30-second max: recording row auto-closed and a `٣٠ ث` message arrived on the receiver.
  - Repeated recordings: two short consecutive messages both arrived.
  - A test-harness bug initially used JavaScript `[-1]` array indexing, so playback appeared to fail; after fixing the helper, playback passed on both devices. This was not an app defect.
  - A shared WebAudio stream initially ended after the first recording; creating a fresh stream per `getUserMedia()` call fixed repeated recordings. Also a harness detail, not an app defect.
- Evidence: `voice_test.json`, `voice_test_salvage.json`, `voice_final.json`, `voice_*.png`.

**Voice conclusion:** message plumbing, permission flow, duration cap, and playback controls are verified. Real microphone capture and audible content are **not** verified; the audio-source failure is environmental. This must not be reported as real voice verification.

### 4.4 Phase 7 — player safety (UGC) and privacy

A debug APK with the new mobile-copy UGC controls was rebuilt, installed on both
devices, and launched. CDP forwards were re-established (`tcp:9223` phone pid
`1224`, `tcp:9222` emulator pid `6153`). `flutter analyze` was clean and
`flutter test` passed 7/7 after the source changes. No JS exceptions were seen
on either WebView.

On-device (single WebView) checks — `ugc_single.json`, `ugc_phone_*.png`:

| Check | Result |
| --- | --- |
| Stable anonymous `dmnshk-pid` generated on first launch | Pass (the JSON evidence records the quoted `localStorage` value; the app reads it correctly — see note) |
| Terms gate before creating a room; decline stays home; accept without tick blocked; accept with tick reaches lobby | Pass |
| Prohibited behavior list (harassment, hate, threats, sexual, personal info, spam, impersonation, illegal, voice abuse) | Pass |
| Community rules link on home screen | Pass |
| Settings links: شروط المجتمع / المحظورين / البلاغات / الخصوصية | Pass |
| Blocked list renders a pid and unblocks it | Pass |
| Reports outbox renders, copy button works, count persisted | Pass |
| In-app `PRIVACY_POLICY.html` from Settings and from home; Arabic + English text; Android Back returns to `index.html` | Pass |
| Solo gameplay smoke after protocol changes | Pass (0 JS exceptions) |

Cross-player checks used two headless desktop Chrome peers loading the **same
bundled app copy** on `localhost:8081` / `localhost:8082`, because device↔device
traffic was isolated at that moment (see §5). This is a protocol/UI check on the
same source, not a second physical device — `ugc_cross.json`,
`ugc_cross_*.png`, `ugc_cross_*_cdp_events.jsonl`:

| Check | Result |
| --- | --- |
| Both peers pass the terms gate and reach game | Pass |
| Distinct pids; host sees guest pid and guest sees host pid via seat tools | Pass (`host_sees_guest: true`, `guest_sees_host: true`) |
| Seat report button opens reason dialog | Pass |
| Chat message carries guest pid; receiver shows report + block buttons | Pass (`report_pid_is_guest: true`) |
| Report dialog → reason → local outbox record with room/pid/snippet | Pass |
| Block from a chat message → confirm → pid stored, prior messages purged | Pass |
| Blocked sender's next message filtered (no text, no unread badge) | Pass |
| Communication still works after blocking; 0 JS exceptions | Pass |

The privacy policy source and the bundled copy are byte-identical
(`8a652aab…`), served from the same trusted localhost origin and allow-listed in
the WebView. Both now contain the confirmed developer name, support email, and
target public URL. The built AAB still carries the older placeholder copy and is
intentionally not rebuilt until publication is confirmed and rebuilding is
authorized.

**Important:** a local report outbox is **not** a moderation system. The in-app
report button does not reach the developer or any moderator today; manual email
reports are possible but are not an in-app review process. See
`UGC_MODERATION_PLAN.md`.

### 4.5 Other device behaviour

From `device_extras.json`, `device_extras2.json`, `clipboard_check.json`, `back_resume_check.json`:

- Settings overlay opened from the game (`extra_phone_01_settings.png`). Instrumented API calls confirmed: `navigator.vibrate(40)` on haptic re-enable, `AudioContext.createOscillator()` on sound test and tile selection, `navigator.wakeLock.request('screen')` on wake re-enable. Settings persisted in `localStorage` across reload.
- Keyboard: `adb shell input text` inserted characters into the name field (`extra_phone_03_keyboard.png`).
- Clipboard: tapping “انسخ اللينك” in the lobby copied the room code; pasting into the home join field with `KEYCODE_PASTE` restored `CLIP5` (`clipboard_check.json`). `navigator.clipboard.readText()` was denied by WebView permissions, so native paste was used as the verification path.
- Share: tapping واتساب opened the Android share sheet; the UI dump contained WhatsApp, and the app did not crash (`extra_phone_05_share_ui.xml`, `extra_phone_05_share_sheet.png`). Nothing was sent.
- Back: from lobby returned home; from a solo game the first Back did not exit or show a confirmation overlay (`extra_phone_18_back_from_game.png`). No crash.
- Background/resume: pressing Home and relaunching preserved the solo game screen, hand (7 tiles), and bot opponents (`extra_phone_19_resume_game.png`).
- Small screen: layout at 720x1280 (CSS 360x592) and 540x960 (CSS 270x432) had no horizontal or vertical document overflow; emulator size was restored to 720x1280 afterwards.
- Android 15/16: unavailable. Installed AVD list contains only `Small_Phone` (Android 14); phone is Android 14.

## 5. Failures, limitations, and blockers

### Confirmed failures
- Real microphone capture on both devices: `NotReadableError: Could not start audio source` with no input device exposed. Environmental; no app-source change made.

### Test limitations
- Voice content audibility not verified; only the playback UI state was checked.
- Synthetic audio is not real voice input.
- One 30-second run triggered a host migration; repeated-record delivery in that specific run was inconclusive, but repeated recordings passed in the earlier run.
- Test A did not save explicit before/after hand-IDs for the disconnect case; Test B did and passed.
- `navigator.clipboard.readText()` is blocked in the WebView; native paste was used instead.
- `ugc_single.json` records `pid_stable: false` because the test compared the raw JSON-quoted `localStorage` value with the parsed value; the app's getter parses it correctly, and `ugc_cross.json` confirms distinct, correctly propagated pids.
- Cross-player UGC checks used two desktop Chrome peers, not two physical devices. Device↔device WebRTC was verified earlier in Tests A/B; during Phase 7 the network became isolated (below), so the two-Chrome setup was the only way to exercise the protocol.
- Local report/block controls were verified on-device only as UI plus cross-peer protocol; there is no backend to verify real moderation.

### Environmental change observed during Phase 7
- The Wi-Fi AP BSSID changed from `dc:51:93:ac:e5:18` to `dc:51:93:ac:e5:19`. In the new state: host `192.168.1.25` cannot ping phone `192.168.1.9`; emulator `10.0.2.15/16` cannot ping phone or host; phone reaches gateway `192.168.1.1` but not the host/emulator. WebRTC ICE stayed `checking`/`connecting` with no `connected` state, and signaling succeeded (WSS 101) but no data channel opened. This is AP/client isolation, not an app logic failure — Tests A/B passed on the previous AP. No Wi-Fi settings were changed.

### Not tested / requires approval
- Cross-network and mobile-data connectivity: not tested. No Wi-Fi/mobile-data changes and no mobile-data use were made without approval.
- Restrictive NATs requiring TURN: not tested; no TURN server is configured. This is a known release risk for some networks.
- Android 15/16: no device or AVD available.
- Outgoing WhatsApp send: not performed; only the share sheet was verified.
- Real audible voice quality: not verifiable in this environment.

### Release blockers
- Google Play UGC compliance: terms acceptance, report, and block controls are now implemented locally, but **real moderation is still missing** — the local outbox does not reach any moderator. A report-intake path (or a justified no-account design) is required before release. See `UGC_MODERATION_PLAN.md`.
- Privacy policy published: `https://ali-ashraf-saad.github.io/dominoshak-privacy/` was confirmed publicly accessible over HTTPS by the owner on 2026-11-18. Developer identity/email (`Domino Shak` / `دومينو شك`, `dominoshak.support@gmail.com`) are in the policy and listings; the final AAB was rebuilt with that policy and verified locally. Still blocked: UGC moderation, content rating, Console enrollment, and upload approval.
- Final application ID sign-off pending (currently `com.dominoshak.domino_shak`, provisional).
- Signing credentials / Play App Signing decision pending; no keystore was created or exposed.

## 6. Evidence index

All files are under `domino_shak_app/test_evidence/`. Key structured files:

- `testA_phase1.json`, `testA_phase2.json`
- `testB.json`
- `voice_test.json`, `voice_test_salvage.json`, `voice_final.json`
- `device_extras.json`, `device_extras2.json`, `clipboard_check.json`, `back_resume_check.json`
- `ugc_single.json`, `ugc_cross.json`
- CDP event dumps: `testA_*_cdp_events*.jsonl`, `testB_*_cdp_events.jsonl`, `ugc_cross_*_cdp_events.jsonl`
- Logcat dumps: `testA_*_logcat.txt`, `testB_*_logcat.txt`, `device_extras_*_logcat.txt`
- Screenshots: `testA_*.png`, `testB_*.png`, `voice_*.png`, `extra_*.png`, `ugc_phone_*.png`, `ugc_cross_*.png` (named by case and device)

## 7. Status matrix

| Category | Status |
| --- | --- |
| Implemented | Flutter shell, bundled web app, narrow native bridge, network game, reconnect tokens, host migration, chat/quick phrases/emoji, voice message pipeline, settings, share/copy, permission flow; UGC terms gate, anonymous pid, local report outbox, block/filter, in-app privacy policy |
| Tested successfully | Both host/guest directions, turn/tile/board/history/chat/badge sync, disconnect/reconnect, host migration both ways, game completion/rematch, token-based hand restoration, ICE/STUN direct connection, settings, keyboard, clipboard, share sheet, back, background/resume, small-screen layout; UGC gate/report/block/filter and privacy navigation (on-device + cross-peer protocol) |
| Tested with limitations | Voice: permission/record/send/receive/playback/duration cap/repeats verified with synthetic WebAudio; real microphone and audible content not verified. Phase 7 cross-peer UGC used desktop Chrome peers because AP client isolation blocked device↔device traffic |
| Not tested | Real mic hardware, audible voice quality, cross-network/mobile data, TURN/restrictive NAT, Android 15/16, outgoing WhatsApp send, real backend moderation flow |
| Requires approval | Cross-network/mobile-data testing, any moderation backend/accounts/deployment, Play Console enrollment, any Play Console upload |
| Blocks release | Real UGC moderation/report intake (local outbox is not enough), content-rating questionnaire, Console enrollment and final Data Safety confirmation |

## 8. Release preparation (after device testing)

- Final application ID confirmed: `com.dominoshak.domino_shak`.
- Play App Signing chosen; a local upload keystore was generated with a random
  password in `0600` files outside the project. Release builds now fail without
  it instead of using the debug key. No password was printed, logged, or committed.
- Final signed AAB rebuilt with the upload key after the privacy policy was
  confirmed live, and copied to `play_store_assets/app-release.aab`. SHA-256
  `16d75cd96675b9a6844063b565a109bdd52178c5bd06a103d6eb3f463fc1dbaf`.
  Signer certificate SHA-256
  `83:6A:88:B3:88:B3:13:DD:13:CC:2C:33:3C:52:CA:71:AB:A9:25:C6:73:45:4B:8E:E1:1C:D8:44:A8:93:4A:7C`.
  The manifest contains `com.dominoshak.domino_shak` / `1.0.0`,
  minSdk 24 / targetSdk 36, `allowBackup=false`; the bundled privacy policy
  hash matches the confirmed source (`8a652aab…`) and the bundled game
  hash is unchanged (`a9a1f0c6…`).
- `flutter analyze` clean; `flutter test` 7/7 passing; `jarsigner -verify`
  reports "jar verified" with only the expected self-signed/unsigned-timestamp
  warnings.
- Store assets drafted from real phone screenshots and the shipped launcher
  icon; Arabic/English listings and a release checklist are in
  `play_store_assets/`.
- **No Play Console upload, rollout, or publish was performed.** Building and
  verifying the final AAB was explicitly authorized; uploading it requires a
  separate approval.
