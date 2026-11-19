# Google Play Data Safety — draft answers

App: **دومينو شك / Domino Shak** (Android only)  
Date: 2026-11-19  
Status: **internal draft — not ready to submit.** Not legal advice. Re-verify every answer against the exact AAB that would be uploaded and close every open item in §8–§9 first. No UGC compliance is claimed.

## 0. Summary / ملخص

- **No developer-collected data** today: there is no developer backend, no account system, no analytics SDK, no ads, and no crash reporting.
- **But data is shared with other users**: the display name, text chat (typed messages, quick phrases, emoji, typing signal), and 30-second-max voice messages go directly to the other players in the room — peer-to-peer online or over the local network in LAN mode. Under Google Play's definitions this counts as **"shared"** even though no server stores it. / الاسم والدردشة والصوت تُرسل مباشرة إلى اللاعبين الآخرين وتُعد «مشاركة» وفق تعريفات Play.
- A **random PeerJS peer ID** is generated per session online and is a device/session identifier for disclosure purposes; it is not used for tracking or advertising. The signaling broker and STUN servers necessarily process the device's **IP address**. In LAN mode the device's **local IP** and room code are shown in the lobby and used only on the LAN.
- **Encrypted in transit**: online yes — WSS/TLS for PeerJS signaling and DTLS-SRTP for WebRTC media/data. **LAN mode uses a local TCP relay on port 8974, not internet encryption; traffic stays on the local network.** / مشفّرة أثناء النقل أونلاين.
- **Deletion**: no server-side data exists; uninstalling the app or clearing app data removes the WebView `localStorage` values. Verify this on the final build (see §8).
- **No account** is created or required.
- **UGC disclosure**: the app contains user-generated content (names, chat, voice). Local terms acceptance, anonymous player ID, block/filter, and a report outbox are shipped, but **no report reaches a reviewer and there is no moderation process**; this remains a release blocker (see §7 and `UGC_MODERATION_PLAN.md`).

## 0.1 Data paths by mode (new)

| Path | What flows | Where it goes | Third parties |
|---|---|---|---|
| **PeerJS / WebRTC signaling (online)** | Peer metadata and game, chat, and voice payloads; random peer ID; IP address | Relayed via `wss://0.peerjs.com`; ICE via the two public STUN endpoints; content then flows directly player-to-player | PeerJS cloud broker and STUN providers |
| **Hosted website** | Static files; the `room` query parameter in `https://liardominoes.gt.tc/?room=CODE` invitation links | The page reads the code and pre-fills the join field; invitation never creates a room | Static host only (no developer-run gameplay server) |
| **Offline LAN (Android only)** | Device local IP, room code, and game/chat/voice messages | Local TCP relay on port 8974 between devices on the same network; **no internet, no PeerJS Cloud, no STUN** | None — traffic stays on the LAN |
| **Reports / blocks** | Report reasons/outbox (`dmnshk-reports`), block list (`dmnshk-block`) | Device-local `localStorage` only; **no reviewer backend implemented** | None |

## 1. Data types — draft declarations

| Play data type | Collected by developer? | Shared? | Where it goes / how it is handled | Purpose | Retention | Arabic note |
| --- | --- | --- | --- | --- | --- | --- |
| Personal info → **Name** (display name) | **No** | **Yes — with other players** | Peer-to-peer online or over LAN to room participants; also stored locally in `localStorage` for convenience | App functionality | Not retained by developer; on device until cleared | الاسم مستعار اختياري ولا يُطلب اسم حقيقي |
| User content → **Messages / other user content** (typed chat, quick phrases, emoji, typing signal) | **No** | **Yes — with other players** | Peer-to-peer online / LAN relay; page memory only (60-message cap); no app server | App functionality | Session memory only; not retained by developer | الرسائل تبقى في ذاكرة الصفحة أثناء الجلسة فقط |
| User content → **Audio** (voice messages, max 30 s) | **No** | **Yes — with other players** | `MediaRecorder` on device, sent peer-to-peer online / LAN; only last 8 payloads kept in memory | App functionality | Session memory only; not retained by developer | الصوت يُسجَّل فقط بعد الضغط على زر الميكروفون |
| Identifiers → **Device or other IDs** (random PeerJS peer ID; local reconnect token; anonymous `dmnshk-pid`) | **No** | Shared with the signaling broker and peers as part of connecting (online); `dmnshk-pid` sent to peers for report/block labeling | Peer ID generated per session online, not persisted; token and `dmnshk-pid` stored only in `localStorage` | App functionality (connectivity/reconnect, player-safety controls) | Peer ID: session only; token and pid: until app data cleared | معرّف عشوائي للاتصال فقط، لا يُستخدم للتتبع |
| Identifiers → **IP address** | **No developer collection or logging** | Processed by third parties (PeerJS signaling, STUN) online; **local IP shown in lobby and used for LAN only in LAN mode** | Visible to `wss://0.peerjs.com` and the two STUN endpoints online; local IP used on the LAN in LAN mode | App functionality (connectivity) | Not stored by the app; third-party retention governed by their policies | عنوان IP يراه وسيط الاتصال وخوادم STUN أونلاين |
| Location, contacts, camera, file storage, payment, health, web browsing, diagnostics/crash logs, advertising IDs | **No** | **No** | Not requested, not used | — | — | لا توجد هذه البيانات |

> **Form-label caution:** Play Console field names change. Confirm whether IP address must be entered under a separate "IP address" data type or under "Identifiers / Device or other IDs" in the current form (open item §9).

## 2. Required / optional and third-party framing

| Question | Draft answer |
| --- | --- |
| Is the data required for the feature? | Name/chat/voice are optional in the sense that a player may use a nickname and may choose not to chat or record; a display name is needed to play online. |
| Collected or shared for "app functionality" only? | Yes. No analytics, advertising, personalization, or profiling purposes. |
| Collected or shared ephemerally? | Chat and voice are in page memory only; the peer ID is per session. The name, settings, and reconnect tokens persist locally by design. LAN messages are transient on the local network. |
| Third-party SDK disclosure? | PeerJS 1.5.4 is bundled locally; no analytics/ad/crash SDK is declared. PeerJS signaling and STUN are third-party network services, not developer servers. LAN mode uses none of them. |
| User can see/delete data in-app? | There is no account or full data-export screen. Settings shows the local blocked-pid list (with unblock) and the local report outbox (with copy/share and clear). Full deletion is still by uninstall/clear app data (§6). |

## 3. Security practices

| Item | Draft answer | Verification needed |
| --- | --- | --- |
| Encrypted in transit | **Online:** WSS (TLS) for PeerJS signaling; DTLS-SRTP for WebRTC data/media. **LAN:** local TCP relay, no internet encryption, traffic on the local network only | Confirm the shipped asset still uses `wss://0.peerjs.com` and that WebRTC is not downgraded |
| Data deletion mechanism declared in the form | Uninstall / clear app data; no server data to delete | Confirm on final build that no residue remains |
| No TURN relay | No TURN configured; if direct connection fails the room fails | Confirm no TURN was added before submission |
| WebView origin locked to `http://localhost:8080` | Yes; other http(s) URLs are handed to Android, others cancelled | Reconfirm in `lib/web_shell.dart` for the shipped build |
| Token-guarded bridge (incl. LAN `lan*` handlers) | Yes, per-launch token validated; LAN events are narrow `CustomEvent`s | Reconfirm in `lib/web_shell.dart` / `lib/bridge.dart` |
| `allowBackup=false` | Declared in the manifest | Reconfirm in the final manifest |
| Microphone instrumentation privacy | `window.__DSVoicePerf` / `[DSVOICE]` log stage timings only; no audio content, names, codes, pids, or IPs | Reconfirm in the shipped asset |

## 4. Account status

**No account, no login, no user ID database, no password, and no email collection.** The random peer/session ID is not an account identifier and is not tied to a person.

## 5. Children / content rating

- Not directed at children under 13; chat with potentially unknown players and voice messages are present.
- Expected content rating is at least **Teen / 12+**; the final rating must come from the Play content-rating questionnaire, which is **developer input** (§9).
- Arabic note: التطبيق غير موجه للأطفال، ويحتوي دردشة وصوتًا مع لاعبين آخرين.

## 6. Deletion and retention

| Location | What is there | How it is removed |
| --- | --- | --- |
| WebView `localStorage` | Display name, settings, reconnect tokens, anonymous `dmnshk-pid`, UGC terms acceptance (`dmnshk-terms-v1`), local blocklist (`dmnshk-block`), report outbox (`dmnshk-reports`) | Uninstall app, or Android Settings → Apps → Domino Shak → Storage → Clear data; reports and blocks can also be cleared/unblocked in Settings |
| Page memory | Room code, chat text, voice recordings, typing state | Ends with the page/session |
| Developer servers | None today | Nothing to delete; deletion/privacy requests go to `dominoshak.support@gmail.com` |
| Third parties | IP address and random peer ID processed by PeerJS/STUN online | Outside developer control; see their policies |
| LAN traffic | Room code, local IP, game/chat/voice messages on the local network | Transient; no device storage by the app |

Caveat from test history: settings **persisted across an APK reinstall** in Phase 4 testing. A reinstall over existing app data is not the same as a clean uninstall; verify the deletion claim with an explicit uninstall + clear-data check on the final build.

## 7. UGC disclosure (required honesty)

| Play question | Draft answer |
| --- | --- |
| Does the app contain user-generated content? | **Yes** — player-chosen names, free-text chat/quick phrases/emoji, and voice messages. |
| Can users report inappropriate content or block other users? | **Locally, yes; end-to-end, no.** The shipped build has a terms gate, report dialog with reason categories, a local report outbox with copy/share, and block/filter by anonymous pid. Reports do **not** reach a reviewer; the outbox is on-device only and is not moderation. |
| Is there a moderation process and published policy? | **No complete process today.** The prohibited-behavior policy is published in-app and in `UGC_MODERATION_PLAN.md`, which also drafts a no-account intake architecture. No hosting, endpoint, reviewer workflow, or appeals channel exists. |
| Submission impact | **Release blocker.** Do not submit or claim UGC compliance until a Play-acceptable reporting/blocking/moderation path and a developer-owned contact are in place. If a backend is added, this Data Safety form must be amended to declare the report data the developer then collects. |

## 8. Verification checklist against the shipped build

| # | Item to verify | Expected | Status / source | Needs developer input? |
| --- | --- | --- | --- | --- |
| 1 | No developer backend, accounts, or databases | None in shipped app | Documented in `PRIVACY_AND_DATA_SAFETY.md`; re-check final AAB | No — re-verify |
| 2 | No analytics, ads, or crash-reporting SDK | Not in dependencies or build | Documented; **no dependency audit was run for these documents** | No — re-verify |
| 3 | Bundled PeerJS endpoint | `wss://0.peerjs.com` only | Documented in `PRIVACY_AND_DATA_SAFETY.md` | No — re-verify |
| 4 | STUN endpoints | `stun:stun.l.google.com:19302`, `stun:global.stun.twilio.com:3478` | Documented; real-device report confirms direct host/srflx candidates | No — re-verify |
| 5 | No TURN | No relay candidate configured | Real-device report B3: no TURN candidate | No — re-verify |
| 6 | Chat/voice stay in page memory | No server upload of content | Documented architecture; code review on final build | No — re-verify |
| 7 | Voice length cap | 30 s max auto-send | Real-device test V4 passed with synthetic audio; real mic capture unverified | No — note limitation |
| 8 | Mic permission timing and origin | On tap only; WebView grants only `localhost:8080` | Phase 4 and real-device V1 verified UI/flow; `MODIFY_AUDIO_SETTINGS` added for routing | No — re-verify |
| 9 | `localStorage` keys and backup exclusion | Name/settings/tokens/pid/terms/blocklist/reports; `allowBackup=false` | Phase 4 + Phase 7 (`ugc_single.json`, `ugc_cross.json`); re-check final manifest | No — re-verify |
| 10 | Clean uninstall clears local data | No name/settings/tokens/pid/reports remain | **Not verified**; reinstall preserved data earlier | No — verify on final build |
| 11 | Encryption in transit / LAN scope | WSS + DTLS-SRTP online; LAN local TCP only | Documented; confirm on final build | No — re-verify |
| 12 | UGC controls/moderation | Terms acceptance, report/block, review path | Local controls **shipped and tested**; real moderation path still a **blocker** | **Yes** |
| 13 | Public HTTPS privacy-policy URL | Stable hosted URL in Console and in-app | **Confirmed live:** `https://ali-ashraf-saad.github.io/dominoshak-privacy/`; in-app policy matches the hosted copy and is bundled in the final AAB | No (enter it in Console) |
| 14 | Developer contact (email/site) | Developer-owned, filled in policy and Console | **Provided:** `Domino Shak` / `دومينو شك`, `dominoshak.support@gmail.com`; inserted in policy and listings | No (enter it in Console) |
| 15 | Final application ID | Sign-off | **Confirmed:** `com.dominoshak.domino_shak` (`RELEASE_DECISIONS.md`); do not change after release | No |
| 16 | Signing / Play App Signing decision | Documented decision | **Chosen:** Play App Signing; local upload keystore created outside the project; final signed AAB rebuilt and verified. Enrollment remains developer-side | No (enroll in Console) |
| 17 | Content-rating questionnaire | Rating selected from actual answers | Not completed | **Yes** |
| 18 | Exact Data Safety field labels (IP address, "shared" definitions) | Match current Console form | Unverified — form UI not reviewed here | **Yes** |
| 19 | Cross-network / restrictive-NAT behavior | Documented or TURN decision made | Not tested; no TURN | **Yes** (decision) |
| 20 | Final AAB equals the build verified here | Same package/hash | Final signed AAB rebuilt with the live policy and verified locally (`16d75cd…`); bundled policy hash matches the source | **Yes** (developer confirms the uploaded artifact) |
| 21 | LAN data path | Local IP/code + game/chat/voice over LAN; no internet/broker | Unit tests + single-device emulator smoke passed; **two-device offline LAN not tested** | No — note limitation |
| 22 | Voice instrumentation logs no content | Stage timings only in `window.__DSVoicePerf` / `[DSVOICE]` | Code review; no recorded runs yet | No — re-verify |

## 9. Open items requiring developer input — flag list

| Item | Why it blocks / matters | Owner |
| --- | --- | --- |
| Developer-owned contact email or official site | **Provided:** `Domino Shak` / `دومينو شك`, `dominoshak.support@gmail.com`; inserted in the policy and listings, still needs to be entered in Play Console | Developer |
| Hosted public HTTPS privacy-policy URL | **Confirmed live:** `https://ali-ashraf-saad.github.io/dominoshak-privacy/`; enter it in the Console field | Developer |
| UGC moderation decision and implementation | Chat/voice without a real report/block/moderation path blocks release | Developer |
| Content-rating questionnaire answers | Determines final rating for chat/voice with strangers | Developer |
| Final application ID | **Confirmed** as `com.dominoshak.domino_shak`; verify it in the Console | Developer |
| Signing keystore / Play App Signing choice | **Chosen** and upload keystore created; Play Console enrollment still required | Developer |
| Exact Play Console Data Safety labels for IP/peer ID and "shared" | Form wording must match the shipped build | Developer / reviewer |
| Decision about TURN and cross-network testing | Functional limitation and potential declaration change | Developer |
| Two-device offline LAN test | LAN data-path evidence is unit/emulator only | Developer |
| Confirmation that the uploaded AAB is the build described here | Answers must describe the shipped artifact | Developer |

## 10. If a moderation backend is added later

The Data Safety answers above would change: report records (report ID, room code, reporter/reported IDs, reason, snippet/hash, timestamp) would become **developer-collected data**, with a new purpose ("app functionality / safety, moderation"), retention period, deletion route, and contact handling. Update this draft, the hosted privacy policy, and the UGC disclosure **before** that build is submitted.
