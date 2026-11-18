# Mobile copy — asset changes

The original website is **not modified**. Everything below is inside the Flutter
project (`domino_shak_app/`) only.

## Source of truth

| File | SHA-256 |
| --- | --- |
| Original `../index.html` (unchanged) | `d9d711ea1601785d89fb1b94845537c330ff95aa6bb412eafd3d95115d4b3e4f` |
| Bundled `assets/web/index.html` (mobile copy) | `a9a1f0c69c33071a10b6aa5ea22e0f952b0b0fd2c9c16eefe36cc7d642c85b48` |
| `PRIVACY_POLICY.html` (source and bundled copy) | `8a652aab2dc9edc398b5aaaa103f79a41ce6022438ba6ef508411773f2d755fd` |

The original hash is recorded in `ORIGINAL_INDEX_SHA256.txt` and was re-checked
after every mobile-copy edit: it still matches.

## Changes to the mobile HTML copy

### 1. Offline assets in `<head>` (original migration)

```diff
-<link rel="preconnect" href="https://fonts.googleapis.com">
-<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
-<link href="https://fonts.googleapis.com/css2?family=Reem+Kufi:wght@500;700&family=Tajawal:wght@400;500;700;800&display=swap" rel="stylesheet">
-<script src="https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js"></script>
+<link href="fonts/fonts.css" rel="stylesheet">
+<script src="vendor/peerjs.min.js"></script>
```

No request leaves the device for fonts or PeerJS; only PeerJS signaling
(`wss://0.peerjs.com`) and STUN are external.

### 2. Player-safety / UGC controls (Phase 7, mobile copy only)

The original website is untouched; these changes exist only in
`assets/web/index.html`:

- Community-terms gate before **creating a room**, **joining a room**, or
  **sending any chat message** (text, quick phrase, emoji, or voice). Declining
  keeps the user on the current screen; acceptance is stored in `localStorage`
  (`dmnshk-terms-v1`).
- Prohibited-behavior list (harassment, hate, threats, sexual content, personal
  information, spam, impersonation, illegal content, voice abuse) shown in the
  terms dialog and from the home screen ("شروط المجتمع").
- Stable anonymous player ID (`dmnshk-pid`) generated on first launch and sent
  with `join`, `welcome`, `state`, `snap`, and every chat message. It has no
  account and is used only to identify reported/blocked senders.
- Report button on each opponent's seat and on every received chat/voice
  message: reason picker stored to a local outbox (`dmnshk-reports`) with room,
  timestamp, and message snippet.
- Block button on the same controls: pid added to `dmnshk-block`, existing
  messages from that pid are removed, and later messages/voice are ignored
  before they reach the chat list or unread badge. Blocked pids can be removed
  from Settings → المحظورين.
- Settings now links to شروط المجتمع, المحظورين, البلاغات, and الخصوصية.
  Reports can be copied/shared for manual handling.
- In-app privacy policy at `PRIVACY_POLICY.html`, reachable from the home
  screen and Settings, with Android back returning to `index.html`.

**Important:** the report outbox is local-only. It is evidence of a report on
the device, **not** a functioning moderation system. See
`UGC_MODERATION_PLAN.md` for the release blocker and the proposed intake
architecture.

### 3. Runtime adaptations (injected shim, not in the HTML)

`lib/bridge.dart` injects a small script at document start. It does not touch
game rules or state; it only adapts the Android shell:

- Lobby buttons: `#copyBtn` → **انسخ الكود**, `#waBtn` → **مشاركة**.
- Lobby hint: replaces the host text "ابعت اللينك لصحابك…" with
  "ابعت كود الطاولة لصحابك…" (Android shares a code, never a URL).
- `#copyBtn` → native clipboard via Flutter + native toast.
- `#waBtn` → Android share sheet (WhatsApp appears there if installed); the
  original link href is never used.
- `#micBtn` → asks Android microphone permission first, then re-clicks the
  button so the original recorder runs unchanged.
- `window.__dominoBack()` → closes ask box / overlay / chat / lobby in that
  order; home means "exit app"; table means "confirm then leave gracefully".
- `window.__dominoLeave()` → drives the game's own settings → leave → confirm
  flow so the host/client sends the proper leave signal.

Every bridge call carries a random 64-hex token generated per launch and
validated natively.

## Vendored libraries and fonts

| Asset | Details |
| --- | --- |
| `vendor/peerjs.min.js` | PeerJS **1.5.4** (same version as the site), SHA-256 `ad5d8870d1e389914f9cba8d35be313c4327c69ee0a221e482e9bf7621136fe5` |
| `fonts/*.woff2` | 12 files from the Google Fonts CSS for Reem Kufi (500/700) and Tajawal (400/500/700/800) |
| `fonts/fonts.css` | Generated from the Google Fonts CSS, with `url(...)` rewritten to local files |
| `fonts/OFL-ReemKufi.txt`, `fonts/OFL-Tajawal.txt` | SIL Open Font License texts (redistribution permitted) |

**Font path fix:** the generated CSS lives in `fonts/fonts.css`, so the first
migration used `url(fonts/xxx.woff2)` and the WebView requested
`/fonts/fonts/xxx.woff2` (404 → fonts failed to decode). Paths are now relative
to the CSS file (`url(xxx.woff2)`).

## Local serving

- `InAppLocalhostServer(documentRoot: 'assets/web', port: 8080)` serves
  `http://localhost:8080/index.html`.
- Fixed port keeps the origin stable, which is required for `localStorage`
  (name, settings, reconnect tokens, terms, blocklist, reports).
- `file://` is never used.
- The privacy policy is served from the same trusted origin
  (`http://localhost:8080/PRIVACY_POLICY.html`) and is in the WebView allow-list.
