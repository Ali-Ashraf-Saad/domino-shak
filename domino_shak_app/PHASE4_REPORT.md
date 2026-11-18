# Phase 4 report — Flutter shell and website migration

Date: 2026-11-18
Scope: Android only. No release AAB was produced.

## 1. Files added or changed

All changes are inside `domino_shak_app/`; `../index.html` is unchanged
(SHA-256 `d9d711ea…4b3e4f`, re-verified).

### Flutter

- `lib/main.dart` — starts `InAppLocalhostServer` on fixed port 8080 before
  `runApp`, stops it on detach, Arabic locale + Material localization, dark
  splash-consistent theme, server-error screen.
- `lib/web_shell.dart` — WebView configuration, navigation allow-list, Android
  back handling, JS alert/confirm/prompt dialogs, microphone permission
  callback, loading/error overlays.
- `lib/bridge.dart` — native share, clipboard, toast, microphone request flow,
  launch-time random token, injected mobile shim (labels, hint, back/leave
  helpers, mic gating).
- `test/bridge_test.dart` — 7 unit tests (room-code validation, token
  validation/uniqueness, shim injection, no localhost invite URL, hooks).
- `pubspec.yaml` — assets, `permission_handler: 12.0.3`, removed unused
  `cupertino_icons`, Arabic description.

### Android

- `AndroidManifest.xml` — INTERNET, RECORD_AUDIO, VIBRATE, mic feature optional,
  Arabic label, `allowBackup=false`, RTL, network security config, package
  queries for external intents.
- `res/xml/network_security_config.xml` — cleartext only for localhost.
- `res/values/strings.xml`, `colors.xml`, `styles.xml`, `values-night/styles.xml`,
  `launch_background.xml` (both), — Arabic name and dark #36210F launch theme.
- `app/build.gradle.kts` — `compileSdk = 36`, `targetSdk = 36`, `minSdk = 24`.
- `MainActivity.kt` — `toast` method channel.

### Web assets

- `assets/web/index.html` — copy of the site; only head links changed to local
  fonts/PeerJS (style+body verified identical).
- `assets/web/vendor/peerjs.min.js` — PeerJS 1.5.4.
- `assets/web/fonts/` — 12 woff2 files, generated `fonts.css` with local paths,
  OFL license files.
- `ORIGINAL_INDEX_SHA256.txt` — original hash record.

### Documentation

- `README.md`, `MOBILE_ASSET_CHANGES.md`, `PRIVACY_AND_DATA_SAFETY.md`, this
  report.

## 2. Implemented features

- Launch straight into the game from a bundled website; no network needed for
  HTML/CSS/fonts/PeerJS.
- Fixed origin `http://localhost:8080` so `localStorage` survives restarts.
- Arabic RTL UI, dark startup, edge-to-edge system bars.
- Native share sheet with room code + joining instructions (no URL); clipboard
  copy with Android clipboard preview and toast.
- Microphone: explanation dialog → Android runtime permission → WebView
  permission only for the trusted origin; denial and permanent-denial paths
  handled; never requested at startup.
- Android back: closes ask box → overlay → chat → lobby; on the table asks for
  confirmation then uses the game's own leave flow and returns home; on home
  exits the app.
- JS `alert`/`confirm`/`prompt` mapped to Arabic Flutter dialogs.
- App pause/resume re-notifies the page so its heartbeat and wake lock resume.
- WebView locked to trusted local content; external http(s)/mailto/tel/whatsapp
  handed to Android; `file://`, `content://`, mixed content, file access,
  third-party cookies, geolocation disabled; debug-only inspection.

## 3. Test environment

- Flutter 3.41.5, JDK 17, Android SDK 36; Gradle build via env vars only.
- Android emulator `Small_Phone`: Android 14 (API 34), x86_64, 720×1280,
  headless with SwiftShader.
- Desktop Chrome used only as a second peer where possible (see limitations).
- `flutter analyze`: **no issues**. `flutter test`: **7/7 passed**.
- Debug APK built and installed:
  `build/app/outputs/flutter-apk/app-debug.apk`.

## 4. Test results

### Verified working

| Test | Result |
| --- | --- |
| Cold launch, bundled fonts/CSS, no console errors | Pass |
| Home screen, Arabic RTL layout | Pass |
| Solo game, medium difficulty (number pick, play, shak overlay, history) | Pass |
| Solo game, hard difficulty | Pass |
| Settings overlay opens; back closes it | Pass |
| Name + settings persistence across app restart and APK reinstall | Pass |
| Room creation, code display, lobby state | Pass |
| Copy code → Android clipboard preview + native toast | Pass |
| Share → Android share sheet with code text, no URL | Pass |
| Android back: lobby → home (room closed) | Pass |
| Android back: table → confirmation → leave → home | Pass |
| Android back: home → app exits | Pass |
| Pause (home) / resume: state preserved, no crash | Pass |
| `alert` and `confirm` bridge, Arabic buttons, correct return value | Pass |
| Screen Wake Lock available and granted in WebView | Pass |
| Vibration API available; VIBRATE permission declared | API present |
| Microphone: explanation → Android dialog → grant reaches media layer | Pass (flow) |
| Two-player online game in the app WebView (host + guest frame):
join, 2/2 start, 14 tiles each, turn play, board and history sync | Pass |
| Chat delivery over WebRTC + unread badge | Pass |
| Client disconnect shows “فاصل” and keeps the host game alive | Pass |
| Reconnect with stored token restores the same seat, 13-tile hand, board | Pass |

### Not verified / blocked

| Item | Reason |
| --- | --- |
| Actual voice recording and playback | Headless emulator has no audio input; `getUserMedia` returns `NotReadableError` after permission is granted. Not an app-code failure, but unproven. |
| Cross-device multiplayer (emulator ↔ desktop) | The sandboxed desktop Chrome produces **zero ICE candidates** (WebRTC blocked); the emulator produces host + srflx candidates. Needs two real devices/networks. |
| Real WhatsApp share target | WhatsApp is not installed on the emulator; the Android share sheet is used, so WhatsApp will appear when installed. |
| Host migration | Host is the app under test; killing it ends the session. Needs two devices. |
| Physical vibration, background audio, real mic gain | No physical device. |
| Android 15/16 specific behavior | Emulator is API 34; targetSdk 36 build installs and runs. |

### Environment problem fixed during testing

`adb install` initially failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE`
(5.8 GB data partition, 92% full). Five unrelated old packages were uninstalled
from the emulator, freeing ~0.8 GB; installation then succeeded.

## 5. Remaining issues and risks

1. **Play UGC policy:** chat + voice messages with no report/block controls.
   This is a release blocker, documented in `PRIVACY_AND_DATA_SAFETY.md`; it was
   not silently ignored and no features were invented to paper over it.
2. **Privacy policy URL / Data Safety form** still required before submission.
3. **No TURN:** restrictive NATs may fail to connect. Needs real-network tests
   and user-facing documentation.
4. **Microphone/voice path** must be tested on a physical device before claiming
   it works.
5. **Host migration / reconnect latency** must be tested on two physical devices.
6. Package ID `com.dominoshak.domino_shak` is still provisional.
7. No release keystore or AAB was created, per instructions.

## 6. Next steps (not done in this phase)

- Test on two real Android phones over Wi-Fi and mobile data; record voice
  messages and replay them.
- Decide and implement the Play UGC reporting/blocking approach.
- Host the privacy policy and complete Data Safety + content rating.
- Finalize application ID, icon, and release signing; then build the AAB.
