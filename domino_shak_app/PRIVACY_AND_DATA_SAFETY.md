# Privacy, data safety, and Google Play notes

Status: **internal draft**. This is not legal advice. A hosted privacy-policy URL must still be entered in Play Console before a Play release (see “Release blockers”). No UGC compliance is claimed.

---

## 1. What the app actually does with data

| Data | Where it goes | Stored? |
| --- | --- | --- |
| Display name (typed at home) | Sent to the other players of the room you join; also shown on your device | Locally in WebView `localStorage` (`dmnshk-name`) |
| Game settings (sounds, vibration, confirmations, volume) | Nowhere; device only | Locally in `localStorage` |
| Room code | Typed/shared manually, pre-filled from an invitation link, or shown in the LAN lobby; used to derive the PeerJS peer ID in online mode | In memory |
| Reconnect token | Used to reclaim your seat after a drop | Locally in `localStorage` (`dmnshk-tok-<code>`) |
| Text chat messages | Sent **peer-to-peer** online, or **over the local network** in LAN mode, to the room's players | Not stored by the app; kept in page memory only (60-message cap) |
| Voice messages | Recorded on the device with `MediaRecorder`, sent peer-to-peer online or over LAN; max 30 s | Not stored by the app; only the last 8 payloads are kept in page memory |
| Typing indicator | Small transient `{t:'typing', on}` signal sent to the room in online/LAN play | Not stored; not counted as a chat message |
| Peer ID | Random ID created by the PeerJS client (online mode only) | Not persisted by the app |
| IP address | Necessarily processed by the PeerJS signaling broker and STUN servers online; in LAN mode the **device's local IP** is shown in the lobby and used for the LAN connection | Not stored by the app |
| Report records | Device-only outbox (`dmnshk-reports`); **no reviewer backend exists** | Locally in `localStorage` until cleared |
| Block list | Device-only filter (`dmnshk-block`) by anonymous pid | Locally in `localStorage` until unblocked/cleared |

There is **no account system, no analytics, no ads, no crash reporting, and no backend server operated by this project**. No UGC moderation/compliance is claimed.

### Third parties involved at runtime

- **PeerJS public cloud broker** — `wss://0.peerjs.com` (signaling only). It sees the random peer ID and the connecting IP address, and relays peer metadata plus game/chat/voice payloads between players, like any WebSocket broker.
- **STUN** — `stun:stun.l.google.com:19302` and `stun:global.stun.twilio.com:3478` (discovering the public address for a direct connection).
- **No TURN server is configured.** Media and messages travel directly between players; if a direct connection cannot be established, the room does not work instead of being relayed through a third party.
- **Public website host** — `https://liardominoes.gt.tc/` serves static files and receives ordinary web requests, including the `?room=CODE` query parameter in invitation links. No developer-run server processes gameplay there.
- **LAN mode** — no third-party broker, no STUN, no internet; traffic stays on the local network between the devices.

Because PeerJS signaling and STUN are third-party services, the app cannot claim “no data is collected”. The honest statement is: the game has no developer-run backend and stores nothing remotely, but network metadata (IP address, random peer ID) is processed by those public services to connect players.

---

## 2. Data paths by mode

| Mode | Path details |
|---|---|
| **Online (Android / web)** | PeerJS/WebRTC signaling via `0.peerjs.com`: peer metadata and game, chat, and voice payloads are relayed between players. IP address and random peer ID are processed by the broker and STUN servers. No developer server receives content. |
| **Hosted website** | Static files from `https://liardominoes.gt.tc/`; the `room` query parameter in `?room=CODE` invitation links is read by the page. The generated web project was deployed to the live host on 2026-11-19 and statically verified there (no cross-platform gameplay test yet); see `WEB_DEPLOYMENT_GUIDE.md`. |
| **Offline LAN (Android only)** | The host's device-local IP (e.g. `192.168.43.x`; the emulator showed NAT `10.0.2.16`) and room code are shown in the lobby. Game, chat, and voice messages travel over the LAN through the Dart TCP relay on port 8974. **No internet, no PeerJS Cloud, no STUN.** LAN mode is not available in a hosted browser (`window.dsLan` is Android WebView only). |
| **Reports / blocks** | Report dialog writes a local-only outbox (`dmnshk-reports`); block/filter is local (`dmnshk-block`). **No reviewer backend, intake endpoint, or moderation process is implemented.** |

---

## 3. Microphone

- `RECORD_AUDIO` is the sensitive permission; `INTERNET`, `MODIFY_AUDIO_SETTINGS`, and `VIBRATE` are normal permissions. `MODIFY_AUDIO_SETTINGS` was added to route microphone capture correctly in Android WebView.
- `getUserMedia` has **one** call site, inside `startRec()`, after an explicit tap. It is **never requested at startup**; there is no warm-up or background permission request.
- Tapping the voice button shows an in-app Arabic explanation (`بيجهّز الميكروفون…`); only then does Android show the runtime dialog.
- Denial is handled gracefully: distinct Arabic messages for not-allowed, no-device, busy/unreadable, and overconstrained cases; the rest of the game still works.
- The WebView `onPermissionRequest` only grants `MICROPHONE` for `http://localhost:8080`; every other origin/resource is denied.
- Audio is recorded only while the record UI is active (max 30 s), with a live level meter. Tracks are stopped on cancel/fail/stop/background, the `AudioContext` is closed, and RAF is cancelled.
- Timing instrumentation records stage names only (`window.__DSVoicePerf`, `[DSVOICE]` debug logs). **No audio content, data URLs, names, room codes, pids, or IPs are logged.**

---

## 4. Other permissions and device access

| Permission / API | Purpose | Notes |
| --- | --- | --- |
| `INTERNET` | PeerJS signaling + WebRTC (online mode) | Required |
| `RECORD_AUDIO` | Voice messages | Runtime, on demand |
| `MODIFY_AUDIO_SETTINGS` | WebView microphone audio routing | Normal permission |
| `VIBRATE` | Haptic feedback (`navigator.vibrate`) | Normal permission |
| Local TCP sockets (LAN mode) | LAN relay on port 8974 | Android WebView only; no new permission |
| Clipboard | Copy invitation link / room code | Only via the copy button |
| Share sheet | Share invitation | Shares the full `https://liardominoes.gt.tc/?room=CODE` URL with the room code as a fallback |

No location, contacts, camera, or storage access, and no background services. `allowBackup` is disabled, so `localStorage` is not included in Android cloud backups.

---

## 5. Data Safety form — draft answers

These must match the final build and be reviewed before submission. Peer-to-peer or LAN transfer of chat/voice/name to other players counts as “sharing” under Play’s definitions even though no server stores it.

- **Data collected:** none by the developer (no server, no SDK analytics).
- **Data shared:**
  - *Name* — shared with other players in the room (online peer-to-peer or LAN); purpose: app functionality; optional (any nickname works); not stored by developer.
  - *Messages (text chat, quick phrases, emoji, typing signal)* — shared with room participants; app functionality; optional; not stored.
  - *Audio (voice messages)* — shared with room participants; app functionality; optional; not stored.
- **Device or other IDs:** a random PeerJS peer ID is generated per session online and sent to the broker; an anonymous `dmnshk-pid` labels chat for local report/block. Neither is used for tracking.
- **IP address:** processed by third-party signaling/STUN online; in LAN mode the device's local IP is shown in the lobby and used for the connection.
- **Encrypted in transit:** yes for online — WSS (TLS) for signaling, DTLS-SRTP for WebRTC media/data. **LAN mode uses a local TCP relay and is not internet-encrypted; traffic stays on the local network.**
- **Data deletion:** no accounts and no server-side storage; deleting the app removes local name/settings/tokens/report/block data. Contact address (to be filled in) handles requests.
- **Children:** the app is not directed at children under 13; chat with strangers requires a content rating of at least “Teen/12+”.

---

## 6. Privacy policy — draft text to host

> **سياسة الخصوصية — دومينو شك**
>
> آخر تحديث: …
>
> «دومينو شك» لعبة دومينو أونلاين. لا يوجد حساب ولا خادم خاص بالمطوّر، ولا
> نجمع بيانات شخصية على أي خادم تابع لنا.
>
> - **الاسم:** الاسم الذي تكتبه يظهر للاعبين في نفس الطاولة فقط، ويُحفظ على
>   جهازك لتعبئته تلقائيًا في المرة القادمة. يمكنك استخدام أي اسم مستعار.
> - **الدردشة والرسائل الصوتية:** تُرسل مباشرة من جهازك إلى أجهزة اللاعبين في
>   الطاولة (اتصال مباشر Peer-to-Peer أونلاين، أو عبر الشبكة المحلية في وضع
>   «شبكة محلية»). لا نحتفظ بها على أي خادم. الصوت لا يُسجَّل إلا عندما تضغط
>   زر الميكروفون وتوافق على الإذن.
> - **الإعدادات:** تُحفظ على جهازك فقط.
> - **الاتصال:** لإنشاء الاتصال أونلاين نستخدم خدمة PeerJS العامة للتنسيق وخوادم STUN
>   عامة. هذه الخدمات ترى عنوان IP الخاص بك ومعرّف اتصال عشوائي فقط لإتمام
>   الاتصال. في وضع الشبكة المحلية لا يُستخدم الإنترنت، ويظهر عنوان IP المحلي
>   وكود الطاولة داخل التطبيق فقط. لا نستخدم أي تحليلات أو إعلانات.
> - **الميكروفون:** يُطلب فقط عند تسجيل رسالة صوتية، ويمكنك رفضه وتبقى اللعبة
>   تعمل.
> - **البلاغات والحظر:** أي بلاغ أو حظر يُحفظ على جهازك فقط؛ لا يوجد حاليًا
>   خادم لمراجعة البلاغات.
> - **الحذف:** لا نخزّن بيانات على خوادمنا. حذف التطبيق يمسح الاسم والإعدادات
>   من جهازك.
> - **الأطفال:** اللعبة غير موجهة لمن هم دون 13 عامًا، وقد تتضمن دردشة مع
>   لاعبين آخرين.
>
> للاستفسار: … (بريد إلكتروني)

---

## 7. Release blockers (must be resolved before Play submission)

1. **UGC policy (Play “User Generated Content”):** the app has free-text chat and voice messages between players. It ships local controls — community-terms gate, report dialog with reason categories (device-only outbox), and local block/filter by anonymous pid — but **no report reaches a reviewer and there is no moderation process or shared enforcement**. Do not submit or claim UGC compliance while this is unresolved.
2. **Privacy policy URL:** a public, stable URL is required in Play Console; the draft above must be hosted and linked in-app or in the store listing.
3. **Data Safety form:** complete it using the draft in section 5 and verify it against the shipped build.
4. **Content rating questionnaire:** chat/UGC and voice chat affect the rating.
5. **No TURN:** players behind restrictive NATs/symmetric NATs may fail to connect online. Functional limitation; must be tested and documented.
6. **Verified App Links / Asset Links:** blocked by the missing Play App Signing fingerprint and host challenge; see `../APP_LINKS_SETUP.md`.

---

## 8. What was verified

- Microphone is not requested at launch; the explanation and Android runtime dialog appear only after tapping the voice button.
- Granting permission reaches the media layer (the headless emulator failed with `NotReadableError` because it has no audio input device — **actual recording was not verified there**).
- A diagnostic build on one physical device reported `DSMIC diag: OK tracks=1`; final-APK two-device audible capture is still pending.
- Clipboard copy shows Android’s clipboard preview and a native toast.
- The share sheet opens with the **full invitation URL plus the room code as fallback** (an earlier "code only" note is stale).
- No external fonts or scripts are fetched; the bundled PeerJS is used.
- Invitation URL/parse unit tests pass; emulator cold/warm prefill and local-browser `?room=TEST12` prefill were observed.
- LAN relay unit tests and a single-device emulator LAN smoke passed; two-device offline LAN is not tested.

See `../PHASE5_FEATURE_REPORT.md` for the consolidated evidence.

---

## 9. Related documents

- `DATA_SAFETY_SUBMISSION.md` — Play Data Safety draft answers.
- `UGC_MODERATION_PLAN.md` — proposed moderation architecture; nothing approved.
- `../CHAT_IMPROVEMENT_PROPOSALS.md` — implemented chat controls and remaining proposals.
- `../VOICE_RECORDING_PERFORMANCE.md` — voice instrumentation and pending measurements.
- `../NETWORK_COMPATIBILITY_MATRIX.md` — tested and untested modes by device pair.
