# دومينو شك — Android app

Flutter shell that bundles the existing Arabic domino web game and serves it to
a single WebView from `http://localhost:8080`. The game logic stays in
JavaScript; Flutter only provides the container, native sharing/clipboard, and
microphone permission handling.

The original website at `../index.html` is **not modified**. See
`MOBILE_ASSET_CHANGES.md` for the exact differences in the bundled copy.

## Requirements

- Flutter 3.41.5 (`/home/ali/flutter`) with Dart 3.11
- JDK 17 for Gradle
- Android SDK platform 36
- Android device/emulator with Android 7.0+ (minSdk 24, targetSdk 36)

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:/home/ali/flutter/bin:$PATH"
```

## Run

```bash
flutter pub get
flutter run                 # debug on a connected device
flutter analyze
flutter test
flutter build apk --debug   # build/app/outputs/flutter-apk/app-debug.apk
```

The final signed release AAB is at
`play_store_assets/app-release.aab`. It was rebuilt after the privacy policy was
confirmed live over HTTPS, and contains the confirmed developer details and
updated policy. It is verified locally but **has not been uploaded** to Google
Play. See `RELEASE_DECISIONS.md` and `play_store_assets/RELEASE_CHECKLIST.md`
for the remaining blockers.

## Structure

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Starts/stops `InAppLocalhostServer` on port 8080, Arabic Material app, server-error screen |
| `lib/web_shell.dart` | WebView settings, navigation allow-list, back handling, JS dialogs, WebView permission requests |
| `lib/bridge.dart` | Token-validated JS bridge: share, copy, toast, mic requests; injected shim |
| `lib/bridge_test.dart…` (`test/`) | Unit tests for tokens, room codes, shim hooks |
| `assets/web/` | Bundled website, PeerJS 1.5.4, local fonts + licenses |
| `android/.../MainActivity.kt` | Native toast channel |
| `android/.../AndroidManifest.xml` | Permissions, RTL, label, network security config |
| `android/.../res/xml/network_security_config.xml` | Cleartext only for localhost/127.0.0.1 |

## Notes

- `permission_handler` is pinned to **12.0.3**; newer versions require AGP 9 /
  compileSdk 37 and fail on this toolchain.
- `InAppLocalhostServer` uses `start()` / `close()` in 6.1.5.
- The bridge token is random per launch and required by every handler.
- The WebView may only navigate inside `http://localhost:8080`; other http(s)
  URLs are handed to Android and everything else is cancelled.
- `file://`, `content://`, mixed content, third-party cookies, file access and
  geolocation are disabled.
- Screen Wake Lock is supported by this WebView (verified), so `wakelock_plus`
  was not added.
- Release signing reads an upload-key properties file from outside the project
  via `DOMINO_UPLOAD_KEY_PROPERTIES`; release builds fail rather than fall back
  to the debug key. No secret is stored in the repository.

## Documents

- `MOBILE_ASSET_CHANGES.md` — migration details and checksums
- `PRIVACY_AND_DATA_SAFETY.md` — original data-flow and permission draft
- `PRIVACY_POLICY.html` — in-app privacy policy (also bundled in `assets/web/`)
- `DATA_SAFETY_SUBMISSION.md` — Play Data Safety draft and developer-input register
- `UGC_MODERATION_PLAN.md` — why local-only reports block release; proposed intake
- `PHASE4_REPORT.md` — what was implemented in Phase 4
- `REAL_DEVICE_TEST_REPORT.md` — device/emulator results, UGC/privacy checks, limitations
- `RELEASE_DECISIONS.md` — confirmed application ID, signing, contact details, and approval limits
- `../privacy_site/` — GitHub Pages-ready privacy policy and exact publish steps
- `play_store_assets/` — draft icon, feature graphic, real screenshots, listings, checklist

## License

Released under the [MIT License](../LICENSE).

Bundled third-party components keep their own licenses, including the Reem Kufi
and Tajawal fonts (SIL Open Font License, see `assets/web/fonts/`) and PeerJS.

## Release status

The mobile copy now includes a community-terms gate, anonymous player ID, local
report outbox, block/filter controls, and an in-app privacy policy. These are
**local controls only**: no report reaches a moderator, so Google Play UGC
compliance still blocks release. See `UGC_MODERATION_PLAN.md`. Do not create a
release AAB, change the application ID, or upload to Play Console without the
user's explicit approval.
