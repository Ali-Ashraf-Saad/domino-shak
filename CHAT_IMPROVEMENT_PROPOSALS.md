# Chat improvements — implemented controls and remaining proposals

**Date:** 2026-11-19  
**Status:** **Chat safety and typing indicator implemented; several proposals remain open.** Local report/block are shipped, text escaping and flood/length limits are in place, and a backward-compatible typing indicator was added. Delivery/retry states, reply-to, reactions, mute/notifications, and a shared blocklist/moderation backend are **not implemented**.

---

## Status categories used in this document

- **Implemented** — code exists in the build.
- **Tested successfully** — recorded passing test with named evidence.
- **Tested with limitations** — partial evidence only.
- **Not tested** — no recorded test exists.
- **Requires approval or external config** — needs a backend, hosting, or a decision.

---

## 1. Scope

This document covers text chat, quick phrases, emoji, voice-message bubbles, and chat-safety controls in the bundled web game. It records what was actually implemented in this phase and what is still a proposal.

Canonical implementation source:

`/home/ali/Documents/DominoGame/domino_shak_app/assets/web/index.html`

The Phase 0 hash `a9a1f0c6…` is stale; re-verify the current hash with `sha256sum` before relying on it (the file changed in this phase). The deployable copy is generated in `domino_shak_web/` by `tools/sync_web_assets.sh`.

---

## 2. Current implementation (what is really there)

**Status: Implemented.**

- Text input in the in-game chat panel; `Enter` sends.
- Text is escaped with `esc()` before rendering; incoming message structures are validated before use.
- **80-character cap** on chat text.
- **600 ms per-seat flood limit** on chat sends, plus a **60-message cap** on the chat log.
- Only the **last 8 voice payloads** are retained (to bound memory).
- Blocked-player filtering by pid already existed and is preserved: block hides past and future messages from that pid on the local device.
- Ten fixed Arabic quick phrases and sixteen emoji buttons (`#quickBar`, `#emoBar`), unread counter/badge and chat preview bubble, bubbles/timestamps/RTL layout — all preserved.
- Voice messages recorded with `MediaRecorder`, sent as a data URL with a `dur` field, with play/progress and an autoplay queue (see `VOICE_RECORDING_PERFORMANCE.md`).
- Chat messages carry a `pid` (anonymous per-install ID) and are relayed peer-to-peer through the host (or through the LAN relay in LAN mode).
- Community-terms gate before chat (`dmnshk-terms-v1`).
- Local report dialog with reason categories; reports go to a device-only outbox (`dmnshk-reports`). **No reviewer backend exists.**
- In-app privacy policy link.

### Typing indicator (new this phase) — Implemented

- `hostData` handles `d.t === 'typing'` and `hostTyping` broadcasts `{t:'typing', from, on}` to the room.
- `clientData` handles `d.t === 'typing'` via `showTyping`.
- Input, blur, and send call `notifyTyping`, with a **1.5 s throttle** on `on` and a **2.6 s auto-hide** timer.
- The indicator is an extra field/message type; old clients ignore it, so the protocol stays backward compatible. It is not counted as a chat message in unread logic.

Earlier tests covered two-player chat both directions and synthetic voice send/receive/playback. Real two-device voice capture with the final APK is still pending; the typing indicator has no separate recorded gameplay test yet (code-level implementation only).

---

## 3. Current limitations

| # | Limitation | Status now |
|---|---|---|
| L1 | Reports only write to `localStorage`; no reviewer sees them | **Open — Requires approval/external config** (Play UGC release blocker) |
| L2 | Blocking is local to one device and uses rotating session pids | **Open — Requires backend**; a shared/signed blocklist is not implemented |
| L3 | Chat history is page-memory only | **Partially bounded** (60-message cap, last 8 voice payloads); no on-device archive |
| L4 | No delivery or read receipts | **Open — not implemented** |
| L5 | No typing indicator | **Resolved** — implemented this phase (code-level; no dedicated gameplay test) |
| L6 | No queued retry when the peer link is down | **Open — not implemented** |
| L7 | No spam/rate limiting in the chat UI | **Resolved** — 80-char cap + 600 ms per-seat flood limit implemented |
| L8 | No automated content screening | **Open — not implemented**; handling is human/local only |
| L9 | Web and app safety UX are not identical yet | **Open** — parity build deployed and statically verified on the public host; no cross-platform gameplay test yet |
| L10 | Voice messages are large data-URL payloads | **Partially bounded** (last 8 kept, 450,000-byte cap); no tuning performed |
| L11 | Autoplay of voice can be blocked by browser policy | **Open** — manual play fallback exists; no UX change this phase |
| L12 | No per-room chat moderation controls | **Open — not implemented** |
| L13 | No reply-to or reactions | **Open — not implemented** |
| L14 | No mute / notification controls | **Open — not implemented** |

These are limitations of the current build, not accusations about any player. All remaining changes must keep the game usable offline and peer-to-peer.

---

## 4. Proposals table

Priority: **P0** = release blocker / safety; **P1** = high-value UX; **P2** = polish.  
Complexity: **Low** = local UI/small JS change; **Medium** = JS + bridge/protocol work; **High** = new service or native + client work.

| ID | Improvement | Priority | Complexity | Status | Backend |
|---|---|---|---|---|---|
| C1 | Real report intake + reviewer queue + appeals | P0 | High | **Not implemented** | Required |
| C2 | Shared, signed enforcement list (block/mute) | P0 | High | **Not implemented** | Required |
| C3 | Full web safety/privacy parity with app | P0 | Medium | **Deployed and statically verified on the public host**; gameplay not tested | None for local controls |
| C4 | Host-side room moderation (mute/kick by pid) | P1 | Medium | **Not implemented** | None |
| C5 | Typing indicator | P1 | Low–Medium | **Implemented** | None |
| C6 | Delivery/read receipts | P1 | Medium | **Not implemented** | None |
| C7 | Send queue + retry + explicit failure | P1 | Medium | **Not implemented** | None |
| C8 | Message length cap + per-sender rate limit | P1 | Low | **Implemented** (80 chars / 600 ms per seat) | None |
| C9 | Bounded on-device chat history | P2 | Medium | **Partially done** (in-memory caps only) | None |
| C10 | Voice payload tuning / compression review | P2 | Medium | **Not implemented** (measure first) | None |
| C11 | Autoplay fallback UX improvement | P2 | Low | **Not implemented** | None |
| C12 | Automated Arabic-aware triage hints | P2 | High | **Not implemented** | External service; not approved |
| C13 | Reply-to / quoting a message | P2 | Medium | **Not implemented** | None |
| C14 | Reactions (emoji reaction on a message) | P2 | Medium | **Not implemented** | None |
| C15 | Mute / notification preferences | P2 | Medium | **Not implemented** | None |

---

## 5. Proposal details

### C1 — Real report intake, review, and appeals (P0, High) — NOT IMPLEMENTED

Reports currently store a local record in `dmnshk-reports`. A minimal HTTPS intake, private store, reviewer workflow, and appeals contact are still required. This is the main Play UGC release blocker; no submission should happen while reports only stay on the device. Research exists in `domino_shak_app/MODERATION_BACKEND_COMPARISON.md`; no option is approved.

### C2 — Shared signed enforcement list (P0, High) — NOT IMPLEMENTED

Each device still has its own local `dmnshk-block` list. A versioned, signed JSON list with a pinned public key is proposed but not built. Without accounts, durable bans remain unreliable because pids rotate; this must be published, not hidden.

### C3 — Full web safety/privacy parity (P0, Medium) — DEPLOYED, STATICALLY VERIFIED

The canonical bundled source has terms gating, report/block controls, and an in-app privacy page. `tools/sync_web_assets.sh` generated `domino_shak_web/`; it passed local checks and was deployed to `https://liardominoes.gt.tc/` on 2026-11-19 via the maintainer's hidden-prompt FTPS tool. Static verification on the live host passed (mode selector, PeerJS, `?room=CODE` prefill, privacy page, no console errors). No cross-platform gameplay test has been run, and report/block controls remain local-only (see C1/C2).

### C4 — Host-side room moderation (P1, Medium) — NOT IMPLEMENTED

Host authority exists for game state; a visible "mute for this table" / kick control by pid is not implemented.

### C5 — Typing indicator (P1, Low–Medium) — IMPLEMENTED

See §2. `d.t === 'typing'` is handled by host and client; `notifyTyping` is throttled 1.5 s with a 2.6 s auto-hide. Additive and backward compatible. No dedicated gameplay test recorded yet.

### C6 — Delivery and read receipts (P1, Medium) — NOT IMPLEMENTED

No unique-message-id acknowledgement or "sent / delivered" state is shown.

### C7 — Send queue, retry, and explicit failure (P1, Medium) — NOT IMPLEMENTED

Messages are not queued when the peer link is down; there is no explicit failure state.

### C8 — Length cap and rate limit (P1, Low) — IMPLEMENTED

80-character cap and 600 ms per-seat flood limit are in the chat send path; the log is capped at 60 messages. This is a local/UI enforcement; a modified client is not re-validated by a server (no backend).

### C9 — Bounded on-device chat history (P2, Medium) — PARTIAL

Only in-memory bounds exist (60 messages, last 8 voice payloads). No persistent history or user-visible "clear chat" control for the log.

### C10 — Voice payload tuning (P2, Medium) — NOT IMPLEMENTED

Measure first via `window.__DSVoicePerf` (`VOICE_RECORDING_PERFORMANCE.md`). Do not change constants based on guesses; keep the `voice`/`dur` fields.

### C11 — Autoplay fallback UX (P2, Low) — NOT IMPLEMENTED

The manual play button remains the fallback; no new affordance was added.

### C12 — Automated triage hints (P2, High) — NOT IMPLEMENTED / NOT APPROVED

Reviewer-tool-only idea; requires an external service and privacy/ToS review. Never auto-ban from a score.

### C13–C15 — Reply-to, reactions, mute/notifications (P2) — NOT IMPLEMENTED

No reply/quote UI, no per-message reactions, and no mute/notification preferences. All would be additive client changes and could be done without a backend, but none exists today.

---

## 6. Test evidence status

**Implemented and checked at code level this phase:**

- chat text escaping (`esc()`), incoming structure validation, 80-char cap, 600 ms per-seat flood limit, 60-message log cap, last-8 voice payload retention;
- typing indicator message flow (`typing` type, `hostTyping`, `showTyping`, `notifyTyping` throttle/auto-hide);
- preserved quick phrases, emoji bar, unread badge, bubbles, timestamps, RTL;
- `flutter analyze` clean and `flutter test` 12/12 pass (not chat-behaviour tests).

**Earlier recorded evidence:**

- two-player text chat in both directions;
- chat payloads and local UGC controls on-device and cross-peer browser tests;
- synthetic voice send/receive/playback.

**Not tested:**

- typing indicator end-to-end between two devices or web ↔ Android;
- web ↔ Android chat/voice on a deployed host;
- any report reaching a reviewer;
- shared blocklist behaviour;
- C1–C4, C6, C7, C9–C15 proposals;
- mixed old/new client rooms after additive protocol changes.

Each implemented proposal needs a written gameplay test note before it can be called fully done; code inspection alone is not enough.

---

## 7. Backend requirements and constraints

- **Required for C1/C2 (P0):** HTTPS intake, private report store, reviewer workflow, appeals contact, signed blocklist publication, retention/audit rules, privacy/Data Safety updates.
- **Unknown:** whether the current host supports PHP and a database. Do not assume it.
- **Not approved:** any account, domain, paid tier, deployment, or service signup.
- **Hosting limits:** static HTML/CSS/JS only; no Node/Python/custom servers; `/.well-known/` is behind a JavaScript challenge (`APP_LINKS_SETUP.md`).
- **Local-only controls can stay:** they do not need a backend, but they do not solve the Play UGC blocker.
- **No release claim:** UGC moderation remains a release blocker until a real intake → review → action loop exists. No UGC compliance is claimed.

---

## 8. Related documents

- `domino_shak_app/UGC_MODERATION_PLAN.md` — local controls, proposed backend, decision gates.
- `domino_shak_app/MODERATION_BACKEND_COMPARISON.md` — option research; nothing approved.
- `domino_shak_app/PRIVACY_AND_DATA_SAFETY.md` — data paths and disclosures.
- `WEB_DEPLOYMENT_GUIDE.md` — generated web project and deployment blockers.
- `VOICE_RECORDING_PERFORMANCE.md` — voice instrumentation and pending measurements.
- `PHASE5_FEATURE_REPORT.md` — consolidated test evidence.
