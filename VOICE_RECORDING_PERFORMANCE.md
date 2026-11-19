# Voice recording — instrumentation and performance measurement plan

**Date:** 2026-11-19  
**Status:** **Instrumentation implemented; measurements PENDING.** Timing hooks and reliability fixes are in the bundled web game, but no before/after numbers have been collected. This document deliberately contains **no measured values**. A final-APK two-device capture test is still pending.

---

## Status categories used in this document

- **Implemented** — code exists in the build.
- **Tested successfully** — recorded passing test with named evidence.
- **Tested with limitations** — partial evidence (one device, diagnostic build, emulator, or synthetic audio).
- **Not tested** — no recorded test exists.
- **Requires approval or external config** — needs a second device, a build, or a decision.

---

## 1. Purpose

This document records the voice instrumentation that was added and defines how to measure latency and reliability **before and after** any further optimisation. All values in the before/after tables remain `PENDING` until a test run records them.

The feature under test is the 30-second voice message in the bundled web game (`domino_shak_app/assets/web/index.html`), running inside the Android WebView and in a desktop/mobile browser.

---

## 2. Current implementation facts

**Status: Implemented.**

- A source audit confirmed `getUserMedia({audio:true})` has exactly **one** code call site, inside `startRec()` (plus one explanatory comment). There is **no warm-up** and no call at app/page startup.
- `startRec()` immediately shows `بيجهّز الميكروفون…` for visual feedback and guards against a second tap while the mic is busy.
- If `navigator.mediaDevices` or `MediaRecorder` is missing, the game shows a browser-unsupported message and does not open the microphone.
- Permission state is checked before requesting; distinct Arabic error messages exist for `NotAllowedError`/`PermissionDeniedError`, `NotFoundError`/`DevicesNotFoundError`, `NotReadableError`/`AbortError`/`TrackStartError`, and `OverconstrainedError`.
- Mime preference order: `audio/webm;codecs=opus`, then `audio/webm`, then `audio/mp4`; target bit rate about 24 kbit/s when accepted.
- A live level meter (`#recLevel`, driven by an `AnalyserNode`) shows input activity while recording.
- Timer stops recording at 30 seconds; a message shorter than about 0.7 seconds is rejected; a blob larger than 450,000 bytes is rejected.
- `FileReader` has an error handler; `onstop` releases the mic and a 1-second fallback release runs if `onstop` never fires.
- All media tracks are stopped on cancel, failure, normal stop, and `visibilitychange` (background); the `AudioContext` is closed and the animation frame (RAF) loop is cancelled.
- On stop, the blob is read as a data URL and sent through the existing chat message path with a `dur` field. The wire format (`data:audio…` Base64 in the chat message) is **unchanged** for compatibility.
- Playback already had play/pause, progress, duration, replay, an autoplay preference, and error handling; it was **not changed** in this phase.

### Non-negotiable constraint

`getUserMedia` must **never** be called except after an explicit user action to record. No pre-opening at startup, no prewarming on page load, and no background permission request. The implementation preserves this rule.

### Permission and audio-routing diagnosis

**Status: Tested with limitations.**

- On the original devices, real microphone capture failed with `NotReadableError`.
- The diagnosed cause was a missing `MODIFY_AUDIO_SETTINGS` permission in the Android manifest. It was added (`AndroidManifest.xml`) and verified with a **diagnostic build on one physical device** (`R9KY9045TRB`), which reported `DSMIC diag: OK tracks=1`.
- The temporary diagnostic code was removed and a final APK was rebuilt with both permissions granted and no startup errors.
- **Final-APK two-device audible capture is Not tested.** One device on a diagnostic build is not proof of release behaviour.

---

## 3. Instrumentation that was added

**Status: Implemented.**

Stage markers are recorded with `vpMark(stage)` into an in-memory array exposed as `window.__DSVoicePerf`, and each completed run is logged with `console.debug('[DSVOICE]', …)`:

| Helper | Role |
|---|---|
| `vpBegin()` | Clears the log, sets `vpT0 = performance.now()`, marks `button_pressed`. |
| `vpMark(stage)` | Appends a `{stage, t}` entry (time relative to `vpT0`) and refreshes `window.__DSVoicePerf`. |
| `vpReport(stage)` | Marks a terminal stage and emits the `[DSVOICE]` debug log. |

Recorded stages:

`button_pressed`, `permission_check`, `getusermedia_request`, `getusermedia_resolved`, `mediarecorder_init`, `first_audio_data`, `mediarecorder_started`, plus failure stages (`getusermedia_failed`, `mediarecorder_failed`, `unsupported`, etc.).

Privacy of the instrumentation: it stores **timing stage names only**. No audio content, data URLs, names, room codes, pids, or IP addresses are logged. The instrumentation is developer/debug output (`console.debug` and a window variable), not telemetry and not sent anywhere.

### How to collect numbers later

1. Open the game in a WebView with debugging enabled (debug builds set `WebContentsDebuggingEnabled`) or in a desktop browser.
2. Tap the voice button and complete an explicit recording.
3. Read `window.__DSVoicePerf` in the console, or filter the console for `[DSVOICE]`.
4. Record device model, Android/WebView or browser version, mime type, duration bucket, and success/failure reason alongside each log.
5. Use the same marker set for the "before" (already captured in code) and any "after" run so the comparison is meaningful.

Keep these numbers **PENDING** until an actual run is recorded; do not infer values from code inspection.

---

## 4. Metrics to measure

All measurements are `PENDING — no test run has recorded them`.

| ID | Metric | How to measure | Before | After | Notes |
|---|---|---|---|---|---|
| M1 | Tap → explanation/permission prompt shown | `button_pressed` → `permission_check` delta | PENDING | PENDING | Native dialog timing may need a Dart-side marker |
| M2 | `getUserMedia` resolution time | `getusermedia_request` → `getusermedia_resolved` | PENDING | PENDING | Success and failure reported separately |
| M3 | First-audio / `MediaRecorder.start()` time | stream resolved → `first_audio_data` / `mediarecorder_started` | PENDING | PENDING | Does not prove audibility |
| M4 | `NotReadableError` / capture failure rate | Count terminal failure stages per attempt, per device | PENDING | PENDING | Report as count/attempts, not a guessed percentage |
| M5 | Stop → send time | `stopRec()` → chat send call | PENDING | PENDING | Includes `FileReader` data-URL conversion |
| M6 | End-of-recording → peer playback start | Timestamps on sender and receiver; same-device loopback first | PENDING | PENDING | Handle clock skew |
| M7 | Payload size | `blob.size` and encoded duration per mime type | PENDING | PENDING | Capped at 450,000 bytes |
| M8 | Peak JS heap / memory during a 30 s recording | Devtools / WebView profiling | PENDING | PENDING | Watch for growth across repeated recordings |
| M9 | Audio glitches / silence in playback | Human listen + waveform on both devices | PENDING | PENDING | Qualitative; record device and network |
| M10 | Autoplay-block frequency | Count blocked `a.play()` attempts | PENDING | PENDING | Track manual-play success separately |

Do not turn these into claims until a test run records actual values. Do not compare a diagnostic build to a final build as if they were equivalent.

---

## 5. Before/after test matrix

| Scenario | Devices / environment | Before | After | Evidence |
|---|---|---|---|---|
| B1 — final APK, explicit record, permission already granted | Physical device `R9KY9045TRB` | PENDING | PENDING | Not created |
| B2 — final APK, explicit record, first-time permission flow | Physical device | PENDING | PENDING | Not created |
| B3 — final APK, two real devices in one room | Physical device 1 + 2 | PENDING | PENDING | Not created |
| B4 — WebView, permission denied | Physical device | PENDING | PENDING | Not created |
| B5 — browser (desktop Chrome-family), explicit record | Desktop browser | PENDING | PENDING | Not created |
| B6 — browser (mobile), explicit record | Phone browser | PENDING | PENDING | Not created |
| B7 — unsupported browser / no `MediaRecorder` | Browser without support | PENDING | PENDING | Not created |
| B8 — weak network / reconnect during or after send | Two devices or browser + device | PENDING | PENDING | Not created |
| B9 — repeated 30 s recordings (memory check) | One device | PENDING | PENDING | Not created |

Every run must confirm: no microphone access before the record button, tracks stopped after each message, no startup permission prompt, and no unexpected network destination for audio.

---

## 6. Test evidence status

**Already recorded (earlier phases / this phase):**

- microphone is not requested at launch; the explanation and Android dialog appear only after tapping the voice button;
- granting permission reached the media layer, after which the headless emulator failed with `NotReadableError` (no audio input device);
- synthetic voice send/receive/playback worked;
- diagnostic build on one physical device returned `DSMIC diag: OK tracks=1`;
- final no-diagnostic APK was installed on that one device with both permissions granted and no startup errors;
- source audit confirmed one `getUserMedia` call site and the presence of the `vp*` timing hooks and `[DSVOICE]` logging;
- `flutter analyze` clean and `flutter test` 12/12 pass (no voice-specific timing values among them).

**Not recorded:**

- any M1–M10 value;
- real audible two-device capture and playback with the final APK;
- web ↔ Android voice;
- release-quality performance data on multiple devices and browsers.

See `PHASE5_FEATURE_REPORT.md` for the consolidated evidence list.

---

## 7. Decision rules for later optimisation

- Change nothing based on intuition. Wait for M1–M10 results.
- If tap delay is dominated by the native permission dialog, improve the explanation UX — do not pre-open the microphone.
- If M7 payloads approach the 450,000-byte cap, evaluate mime/format changes while keeping `voice`/`dur` compatibility.
- If M4 failures remain, re-check manifest permissions and WebView audio routing; do not add background permission requests.
- If M10 autoplay blocks are frequent, improve the manual play affordance rather than bypassing browser policy.
- Keep the wire format and protocol unchanged unless a compatibility review is done first.

---

## 8. Limitations and blockers

- Measurements are pending; this document contains no numbers. `window.__DSVoicePerf` is the collection point.
- The second physical Android device must be available for the final two-device test.
- The final release artifact must be rebuilt from current source before release testing; older signed AABs predate the microphone fix.
- No Play upload or publish was performed.
- Voice content crosses peer-to-peer links; moderation and privacy disclosures remain release blockers (see `CHAT_IMPROVEMENT_PROPOSALS.md` and `domino_shak_app/PRIVACY_AND_DATA_SAFETY.md`).

---

## 9. Related documents

- `CHAT_IMPROVEMENT_PROPOSALS.md` — chat/voice safety controls and remaining proposals.
- `NETWORK_COMPATIBILITY_MATRIX.md` — tested and untested device-pair modes.
- `PHASE5_FEATURE_REPORT.md` — consolidated test evidence.
- `PROJECT_AUDIT_AND_NEXT_STEPS.md` — Phase 0 evidence and device notes.
