# Privacy, data safety, and Google Play notes

Status: **internal draft for Phase 4**. This is not legal advice. A hosted
privacy-policy URL is still required before a Play release (see “Release
blockers”).

## 1. What the app actually does with data

| Data | Where it goes | Stored? |
| --- | --- | --- |
| Display name (typed at home) | Sent to the other players of the room you join; also shown on your device | Locally in WebView `localStorage` (`dmnshk-name`) |
| Game settings (sounds, vibration, confirmations, volume) | Nowhere; device only | Locally in `localStorage` |
| Room code | Typed/shared manually; used to derive the PeerJS peer ID | In memory |
| Reconnect token | Used to reclaim your seat after a drop | Locally in `localStorage` (`dmnshk-tok-<code>`) |
| Text chat messages | Sent **peer-to-peer** to the room's players | Not stored by the app; kept in page memory only |
| Voice messages | Recorded on the device with `MediaRecorder`, sent **peer-to-peer** | Not stored by the app; the recording exists only in page memory |
| Peer ID | Random ID created by the PeerJS client | Not persisted by the app |
| IP address | Necessarily processed by the PeerJS signaling broker and the STUN servers to establish WebRTC | Not stored by the app |

There is **no account system, no analytics, no ads, no crash reporting, and no
backend server operated by this project**.

### Third parties involved at runtime

- **PeerJS public cloud broker** — `wss://0.peerjs.com` (signaling only). It
  sees the random peer ID and the connecting IP address, like any WebSocket
  server.
- **STUN** — `stun:stun.l.google.com:19302` and
  `stun:global.stun.twilio.com:3478` (discovering the public address for a
  direct connection).
- **No TURN server is configured.** Media and messages therefore travel
  directly between players; if a direct connection cannot be established, the
  room does not work instead of being relayed through a third party.

Because PeerJS signaling and STUN are third-party services, the app cannot
claim “no data is collected”. The honest statement is: the game has no
developer-run backend and stores nothing remotely, but network metadata (IP
address, random peer ID) is processed by those public services to connect
players.

## 2. Microphone

- `RECORD_AUDIO` is the only sensitive permission; `INTERNET` and `VIBRATE`
  are normal permissions.
- It is **never requested at startup**. Tapping the voice-message button first
  shows an in-app Arabic explanation; only if the user continues does Android
  show the runtime dialog.
- Denial is handled gracefully: a message explains that the rest of the game
  still works; if permanently denied, the app offers “افتح الإعدادات”.
- The WebView `onPermissionRequest` only grants `MICROPHONE` for
  `http://localhost:8080`; every other origin/resource is denied.
- Audio is recorded only while the record UI is active (max 30 s in the game
  code) and is sent only to the room.

## 3. Other permissions and device access

| Permission / API | Purpose | Notes |
| --- | --- | --- |
| `INTERNET` | PeerJS signaling + WebRTC | Required |
| `RECORD_AUDIO` | Voice messages | Runtime, on demand |
| `VIBRATE` | Haptic feedback (`navigator.vibrate`) | Normal permission |
| Clipboard | Copy room code | Only via the copy button |
| Share sheet | Share room code | Only via the share button; content is the code + instructions |

No location, contacts, camera, storage, or background services. `allowBackup`
is disabled, so `localStorage` is not included in Android cloud backups.

## 4. Data Safety form — draft answers

These must match the final build and be reviewed before submission. Peer-to-peer
transfer of chat/voice/name to other players counts as “sharing” under Play’s
definitions even though no server stores it.

- **Data collected:** none by the developer (no server, no SDK analytics).
- **Data shared:**
  - *Name* — shared with other players in the room; purpose: app functionality;
    optional (a display name is required to play online, but it can be any
    nickname); not stored by developer.
  - *Messages (text chat)* — shared with room participants; app functionality;
    optional; not stored.
  - *Audio (voice messages)* — shared with room participants; app
    functionality; optional; not stored.
- **Device or other IDs:** a random PeerJS peer ID is generated per session and
  sent to the PeerJS broker; not used for tracking.
- **Encrypted in transit:** yes — WSS (TLS) for signaling, DTLS-SRTP for WebRTC
  media/data.
- **Data deletion:** no accounts and no server-side storage; deleting the app
  removes the local name/settings/tokens. Contact address (to be filled in)
  handles requests.
- **Children:** the app is not directed at children under 13; chat with
  strangers requires a content rating of at least “Teen/12+”.

## 5. Privacy policy — draft text to host

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
>   الطاولة (اتصال مباشر Peer-to-Peer). لا نحتفظ بها على أي خادم. الصوت لا
>   يُسجَّل إلا عندما تضغط زر الميكروفون وتوافق على الإذن.
> - **الإعدادات:** تُحفظ على جهازك فقط.
> - **الاتصال:** لإنشاء الاتصال نستخدم خدمة PeerJS العامة للتنسيق وخوادم STUN
>   عامة. هذه الخدمات ترى عنوان IP الخاص بك ومعرّف اتصال عشوائي فقط لإتمام
>   الاتصال. لا نستخدم أي تحليلات أو إعلانات.
> - **الميكروفون:** يُطلب فقط عند تسجيل رسالة صوتية، ويمكنك رفضه وتبقى اللعبة
>   تعمل.
> - **الحذف:** لا نخزّن بيانات على خوادمنا. حذف التطبيق يمسح الاسم والإعدادات
>   من جهازك.
> - **الأطفال:** اللعبة غير موجهة لمن هم دون 13 عامًا، وقد تتضمن دردشة مع
>   لاعبين آخرين.
>
> للاستفسار: … (بريد إلكتروني)

## 6. Release blockers (must be resolved before Play submission)

1. **UGC policy (Play “User Generated Content”):** the game has free-text chat
   and voice messages between players, with **no in-app report or block
   controls**. Google Play generally requires UGC apps to provide reporting,
   blocking, and moderation terms. The original website has none of these.
   Either add report/block to the game (which changes product scope) or
   document a moderation approach accepted by Play. **Do not submit while this
   is unresolved.**
2. **Privacy policy URL:** a public, stable URL is required in Play Console; the
   draft above must be hosted and linked in-app or in the store listing.
3. **Data Safety form:** complete it using the draft in section 4 and verify it
   against the shipped build.
4. **Content rating questionnaire:** chat/UGC and voice chat affect the rating.
5. **No TURN:** players behind restrictive NATs/symmetric NATs may fail to
   connect. This is a functional limitation, not a privacy one; it must be
   tested on real networks and documented in the release notes.

## 7. What was verified in Phase 4

- Microphone is not requested at launch; the explanation dialog and Android
  runtime dialog appear only after tapping the voice button.
- Granting the permission reaches the media layer (the WebView then fails with
  `NotReadableError` on the headless emulator because it has no audio input
  device — **actual recording was not verified**).
- Clipboard copy shows Android’s clipboard preview and a native toast.
- The share sheet opens with the room code and no URL.
- No external fonts or scripts are fetched; the bundled PeerJS is used.
