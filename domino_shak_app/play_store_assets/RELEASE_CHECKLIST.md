# Play release checklist (draft — do not submit)

Status: **pre-submission**. No Play Console upload, rollout, or publish has been
performed. This checklist tracks what is ready and what still blocks release.

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
- [x] Final AAB rebuilt with the updated policy and confirmed developer details after publication; locally verified. Hash recorded below. **Not uploaded.**

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
- [ ] App-signing key enrollment happens in Play Console after the owner's separate upload approval. **Do not upload now.**

## Artifacts

| File | Purpose | SHA-256 |
| --- | --- | --- |
| `icon.png` | 512x512 Play icon (owner-updated appearance) | `8beec35d2d78564cfaff65c497bfbd981f58236c796fd0600eeecfc8df625abd` |
| `feature_graphic.png` | 1024x500 feature graphic (owner-updated appearance) | `039b7eb0f9b09538a57de452ceee94a9efbfe97f95865af657b647ca5c78f3e8` |
| `screenshots/*.png` | 7 real phone screenshots, 1080x1920 | See `SHA256SUMS.txt` |
| `app-release.aab` | Final upload-key-signed AAB (42.7 MB, rebuilt with the live policy) | `16d75cd96675b9a6844063b565a109bdd52178c5bd06a103d6eb3f463fc1dbaf` |
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

Building a signed AAB locally is allowed by the recorded decision; **uploading
it to Google Play is not**. Publishing requires a new explicit approval.
