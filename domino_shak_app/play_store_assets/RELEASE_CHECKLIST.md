# Play release checklist (draft — do not submit)

Status: **web 1.0.10 deployed; AAB 1.0.10 promoted to Closed testing - Alpha on
2026-11-25, with the Internal testing track paused so only Alpha serves the
app**. The Alpha release is under Play review. Nothing has been rolled out to
production. This checklist tracks what is ready and what still blocks production
release.

## Ready

- [x] Final application ID confirmed: `com.dominoshak.domino_shak` (`RELEASE_DECISIONS.md`).
- [x] App icon 512x512: `icon.png` (appearance updated by the owner on 2026-11-18).
- [x] Feature graphic 1024x500: `feature_graphic.png` (appearance updated by the owner on 2026-11-18).
- [x] Seven real on-device (phone) screenshots, cropped to 1080x1920: `screenshots/`.
- [x] Arabic and English listing drafts: `listings/`.
- [x] In-app privacy policy bundled and reachable from home and Settings.
- [x] Privacy/Data Safety/UGC planning docs copied here for review.
- [x] UGC terms gate, anonymous pid, local report outbox, block/filter implemented and tested.
- [x] `flutter analyze` clean; `flutter test` 7/7 passing.

## Blocking — must be resolved before submission

- [x] Developer-owned contact email/site: **provided** — `Domino Shak` / `دومينو شك`, `dominoshak.support@gmail.com`. Inserted in the policy and both listings.
- [x] Public HTTPS privacy-policy URL: `https://ali-ashraf-saad.github.io/dominoshak-privacy/` confirmed publicly accessible over HTTPS by the owner on 2026-11-18.
- [ ] Real UGC moderation/report intake: local outbox only; no reviewer receives reports. `UGC_MODERATION_PLAN.md` design approved but not deployed (deployment needs separate approval). Manual email reports are possible but are not an in-app moderation system.
- [ ] Content-rating questionnaire answers (expect at least Teen/12+ because of chat and voice with strangers).
- [ ] Data Safety answers re-verified against the exact final AAB (`DATA_SAFETY_SUBMISSION.md`).
- [x] Final AAB rebuilt for `1.0.10` with the upload key and the updated web assets; locally verified. Hash recorded below. **Uploaded and published to Internal testing on 2026-11-25.**

## Technical verification to repeat on the final build

- [x] No developer backend, analytics, ads, or crash-reporting SDK markers in the AAB (static check of dependency metadata and `.dex`/`.so` strings).
- [x] Bundled PeerJS 1.5.4 cloud broker (`0.peerjs.com:443` over WSS) verified in the AAB; the app passes a STUN-only `PEER_OPTS` config to both `Peer` constructors. The library's built-in default TURN entry is overridden; real-device Test B3 saw no TURN candidate.
- [x] WebView navigation allow-list still limits http(s) to `localhost:8080` (code and compiled-shell review; runtime device tests were on the earlier debug build).
- [ ] Clean uninstall clears all local data (name, settings, tokens, pid, terms, blocklist, reports). Reinstall is not equivalent to clean uninstall.
- [ ] Real microphone capture on a device with a working audio input (not verifiable in the test environment — synthetic WebAudio only).
- [ ] Two-device multiplayer on a network without AP/client isolation (Tests A/B passed on the previous AP; Phase 7 re-test was blocked by client isolation).
- [ ] Cross-network / restrictive-NAT behavior and TURN decision.

## Signing

- [x] Play App Signing chosen (`RELEASE_DECISIONS.md`).
- [x] Local upload keystore generated with a random password in `0600` files outside the project (`~/.config/domino_shak/`), never printed, logged, or committed. Release builds now fail without the properties file instead of falling back to debug signing.
- [x] Final signed AAB rebuilt with the upload key after URL confirmation: `app-release.aab`, SHA-256 `16d75cd96675b9a6844063b565a109bdd52178c5bd06a103d6eb3f463fc1dbaf`. Signer cert `CN=Domino Shak…`, SHA-256 `83:6A:88:B3:88:B3:13:DD:13:CC:2C:33:3C:52:CA:71:AB:A9:25:C6:73:45:4B:8E:E1:1C:D8:44:A8:93:4A:7C`; `jarsigner -verify` = `jar verified`. Manifest confirms `com.dominoshak.domino_shak`, `1.0.0`, minSdk 24/targetSdk 36, `allowBackup=false`; bundled policy hash matches source and game assets are unchanged.
- [x] Play App Signing enrollment and first AAB upload completed in Play Console
  by the owner's browser session on 2026-11-25. No Play credentials are stored
  in this repository.

## Artifacts

| File | Purpose | SHA-256 |
| --- | --- | --- |
| `icon.png` | 512x512 Play icon (owner-updated appearance) | `8beec35d2d78564cfaff65c497bfbd981f58236c796fd0600eeecfc8df625abd` |
| `feature_graphic.png` | 1024x500 feature graphic (owner-updated appearance) | `039b7eb0f9b09538a57de452ceee94a9efbfe97f95865af657b647ca5c78f3e8` |
| `screenshots/*.png` | 7 real phone screenshots, 1080x1920 | See `SHA256SUMS.txt` |
| `app-release.aab` | Final upload-key-signed AAB, version `1.0.10` (`versionCode 10`) | `b1424ecc68ad4767b77aaededb8a04951c56265319d402f8a7ee2818585a4465` |
| `listings/` | Arabic and English listing drafts | — |
| `PRIVACY_POLICY.html` | Privacy policy copy (confirmed contact + target URL) | `8a652aab2dc9edc398b5aaaa103f79a41ce6022438ba6ef508411773f2d755fd` |

## Privacy-policy hosting

- `../../privacy_site/index.html` is the self-contained GitHub Pages copy of the policy (no in-app back button, canonical URL set).
- Repository: `https://github.com/Ali-Ashraf-Saad/dominoshak-privacy` · Target URL: `https://ali-ashraf-saad.github.io/dominoshak-privacy/`.
- Exact publish steps are in `../../privacy_site/README.md`. Owner confirmed public HTTPS access on 2026-11-18; the AAB was rebuilt and verified locally. **Do not upload** without a separate explicit approval.

## Final AAB verification (2026-11-18)

- `flutter analyze`: no issues. `flutter test`: 7/7 passed.
- Built with `flutter build appbundle --release` and `DOMINO_UPLOAD_KEY_PROPERTIES` pointing outside the project; release signing cannot fall back to debug.
- AAB contents: bundled `PRIVACY_POLICY.html` SHA-256 `8a652aab…` (matches source), `index.html` `a9a1f0c6…` (unchanged), `vendor/peerjs.min.js` `ad5d8870…`; fonts, font licenses, and network security config present.
- STUN-only `PEER_OPTS` is passed to both `Peer` constructors; the PeerJS library's built-in default TURN entry is overridden. No analytics/ads/crash-reporting SDK markers found in the AAB dependency metadata or `.dex`/`.so` strings.
- Signer certificate SHA-256 `83:6A:88:B3:88:B3:13:DD:13:CC:2C:33:3C:52:CA:71:AB:A9:25:C6:73:45:4B:8E:E1:1C:D8:44:A8:93:4A:7C`; `jarsigner -verify` reports `jar verified` (self-signed chain and missing timestamp warnings are expected for an upload key).
- Original website `../../index.html` unchanged: `d9d711ea1601785d89fb1b94845537c330ff95aa6bb412eafd3d95115d4b3e4f`.

### Store-asset update (2026-11-18)

- `icon.png` and `feature_graphic.png` were **intentionally updated by the app owner** to change their appearance; the owner confirmed this. The rewrite also added an identical 5,758-byte PNG `caBX` (C2PA content-credentials) chunk to each file.
- Original hashes (superseded): icon `96a9b3915859a8b54472888310981ea23abf79b3659ae56919f289aa1c552efd`, feature graphic `2b0317c6fcd0eb95736fa9626df1e629ca5c890f63378c85e30ada7a3f7b44b8`.
- Current hashes (recorded in both the artifact table and `SHA256SUMS.txt`): icon `8beec35d2d78564cfaff65c497bfbd981f58236c796fd0600eeecfc8df625abd`, feature graphic `039b7eb0f9b09538a57de452ceee94a9efbfe97f95865af657b647ca5c78f3e8`.
- Visible dimensions verified: 512x512 and 1024x500 RGB, non-blank. The AAB, bundled web assets, privacy policy, original website, and all other checksums are unchanged. Store images are not part of the AAB, so no rebuild is required.

## Reminder

Building a signed AAB locally is allowed. The owner explicitly approved
uploading and updating all remote targets; the web deployment, GitHub release,
and Play Internal testing upload are now complete. Production still needs the
remaining policy/testing items above.

## Final Play build (2026-11-25)

- Version: `1.0.6` (`versionCode 6`, from `pubspec.yaml` `version: 1.0.6+6`).
- Built with `flutter build appbundle --release` and `DOMINO_UPLOAD_KEY_PROPERTIES` outside the project.
- `app-release.aab` SHA-256: `a12411f4cee54f4b59f869b8060828d749a9c3ea2e09ea58719ea19fa66ce1c1`; `jarsigner -verify` = `jar verified`.
- Package `com.dominoshak.domino_shak`; minSdk 24; targetSdk 36; signer SHA-256 `83:6A:88:…:4A:7C`.
- `flutter analyze`: no issues. `flutter test`: 11/11 passed.
- Bundled `assets/web/index.html` matches the canonical source byte for byte (`8004bc8f…71e0`).
- **Change:** invitation links now open in the browser first and show an in-page chooser — «افتح التطبيق» (`intent://…;package=com.dominoshak.domino_shak;end`) or «كمّل في الموقع». `android:autoVerify` was removed from the HTTPS intent filter so Android no longer bypasses the page; the filter stays so the explicit intent can launch the app.
- `assetlinks.json` remains published for a possible future return to verified auto-open.
- This supersedes the 2026-11-21 AAB. First upload target: **Internal testing**.
- Still open before production: real UGC moderation/report intake, content-rating questionnaire, Data Safety verification.

## Current build (2026-11-25) — 1.0.10

- Version: `1.0.10` (`versionCode 10`, `pubspec.yaml version: 1.0.10+10`).
- `flutter analyze`: no issues. `flutter test`: 11/11 passed.
- Built with `flutter build appbundle --release` and `DOMINO_UPLOAD_KEY_PROPERTIES`
  outside the project. Signer cert SHA-256 `83:6A:88:…:4A:7C` (upload key).
- `app-release.aab` SHA-256: `b1424ecc68ad4767b77aaededb8a04951c56265319d402f8a7ee2818585a4465`.
- Release APK SHA-256: `edca328fcbee67e512ae3f3d550eba441df1f351f3ad2cd971849322ac0e56f5`.
- Bundled `assets/web/index.html` SHA-256: `d969a53753e7fd2153ed7e56f4421396a21a0b0e2773c16ac2a9017966895498`.
- UI batch on top of 1.0.6: organised Settings sections; removed content-zoom
  slider (only `−`/`+` remain) and fixed zoom repaint/layout; improved log
  positions and hid log options when the log is off; removed chat swipe hint;
  fixed dialog entry flash.
- Website `domino_shak_web/` deployed to `https://liardominoes.gt.tc/` via
  explicit FTPS; all 24 live files verified byte-for-byte against
  `domino_shak_web/SHA256SUMS.txt` in the browser.
- **Published to Play Internal testing on 2026-11-25** as release
  «1.0.10 - تحسينات الواجهة والتحكمات» (version code 10), with no devices lost
  from the previous compatibility set. The track was then **paused** the same day
  at the owner's request; Play Console now shows it as «غير نشط», with a
  «استئناف مسار الاختبار» button to restore it.
- **Promoted to Closed testing - Alpha on 2026-11-25.** Play Console lists the
  same release there with status «قيد المراجعة» (under review), version code 10,
  178 countries/regions. Alpha remains active; the earlier `1.0.6` alpha release
  is still listed for existing testers.
- Release notes use Play's `<ar>…</ar>` language-tag format.
- Future uploads are wired for Fastlane Supply via `./tools/play_supply.sh`
  (`validate_auth`, `track_info`, `upload_internal`, `upload_alpha`,
  `promote_alpha`); the service-account JSON key is held outside the repository
  and mounted read-only. See `PLAY_CLI_RELEASE.md`. No Play Console credentials
  are stored in this repo. Pausing a track is a Console-only action; the Play API
  cannot delete a predefined track, and halting the release via the API returned
  a Google 500 while Alpha was under review.
- Still open before production: real UGC moderation/report intake, content
  rating, Data Safety verification, and completion of the 12-tester/14-day
  closed test.

