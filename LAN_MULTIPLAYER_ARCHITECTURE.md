# Offline LAN multiplayer — implemented architecture

**Date:** 2026-11-19  
**Status:** **IMPLEMENTED (transport), TESTED WITH LIMITATIONS.** A Dart TCP relay, token-guarded WebView bridge, and a PeerJS-compatible LAN shim now exist in the app and bundled web game. Unit tests pass and a single-device emulator smoke test succeeded. A real two-device offline hotspot test has **not** been performed. This document describes what was actually built and what remains unverified.

---

## Status categories used in this document

- **Implemented** — code exists and is in the build.
- **Tested successfully** — a recorded passing test with named evidence.
- **Tested with limitations** — partial evidence (unit-only, one device, emulator only, or emulator NAT address), not the full target scenario.
- **Not tested** — no recorded test exists.
- **Blocked by hosting** — cannot be completed due to the public host configuration.
- **Requires approval or external config** — needs credentials, a signing fingerprint, or a developer decision.

---

## 1. Goal

Allow two or more Android devices on the same local network (for example a Wi-Fi hotspot with AP/client isolation disabled) to play together with **no internet access**, while leaving the online mode unchanged.

Hard requirements from the recorded decisions (all preserved in the implementation):

- Native Android LAN signalling is used (approved).
- The web game sees it only through a minimal, token-guarded bridge.
- Online mode keeps working exactly as today.
- LAN mode uses **no** PeerJS Cloud, public STUN servers, or public host.
- The historical `index.html` and the public web host are not part of LAN play.

---

## 2. Why online mode cannot do this

Online mode still:

- creates a PeerJS peer against the public cloud broker (`wss://0.peerjs.com:443`);
- uses two public STUN servers for ICE;
- has no local discovery outside the new LAN mode.

With no internet, that path cannot register a peer, so room create/join fails. Adding TURN would not help because TURN is also a public internet service and is explicitly out of scope.

---

## 3. Implemented architecture overview

```text
Android device A (host of a room)
┌──────────────────────────────────────────────────────────┐
│ Flutter / Dart                                           │
│  ├─ bundled web game in InAppWebView (localhost:8080)    │
│  │    └─ LanPeer/LanConn shim → window.dsLan → bridge    │
│  └─ LanService: Dart TCP relay on port 8974              │
│         relays newline-delimited JSON envelopes          │
└──────────────────────────────────────────────────────────┘
                 │ local network only (no internet)
                 ▼
Android device B (guest)
┌──────────────────────────────────────────────────────────┐
│ bundled web game in InAppWebView                         │
│  └─ LanPeer/LanConn shim → window.dsLan → bridge         │
│       → LanService.connect(host IP, 8974, peer id)       │
└──────────────────────────────────────────────────────────┘
```

Game logic and host authority stay in the bundled web game on device A. `LanService` is a **signalling/message relay only**: it does not run the game, store hands, or decide winners. In this first version the TCP JSON channel carries the game messages directly through the `LanConn` shim (no WebRTC ICE in LAN mode), which keeps the decision explicit and avoids any STUN dependency.

---

## 4. Implemented components

### 4.1 `lib/lan_service.dart` — Dart TCP relay

**Status: Implemented and unit-tested (Tested with limitations — no real two-device run).**

- `ServerSocket.bind(InternetAddress.anyIPv4, 8974)` (`LanService.defaultPort`) on the host device.
- Newline-delimited JSON envelopes: `register`, `registered`, `relay`, `peerleft`, `error`, each with `from` (and `to`/`data` for `relay`).
- `Map<String, Socket>` from registered peer id → socket; the relay stamps the sender id itself on routed messages.
- `connect(host, port, id)` on the guest, a 5-second connect timeout, and a `register` envelope on connect.
- `send(to, data)` returns `false` when no client socket is open; unknown peers produce a `peer-unavailable` `error` envelope instead of a crash.
- `localIp()` prefers `192.168.43.x` (typical hotspot), then other `192.168.*` / `10.*` addresses, then the first non-loopback IPv4 address.
- Callbacks: `onMessage`, `onPeerLeft`, `onError`; a `_LineReader` accumulates UTF-8 bytes and tolerates malformed JSON by ignoring it.
- `stopHost()` / `closeClient()` / `dispose()` close sockets and clear peer state.

**Not implemented in the relay:** room-code validation, per-connection rate limits, payload size caps, heartbeats, max-peer count. The LAN room code is validated in the web UI path, but the relay itself accepts any non-empty string `from` id. This is a known limitation, not a hidden security claim.

### 4.2 WebView bridge — `lib/web_shell.dart` + `lib/bridge.dart`

**Status: Implemented.**

Token-guarded handlers exposed to the WebView (all require the per-launch random token):

| JS → Dart | Purpose |
|---|---|
| `lanHost` | Start the local relay (`LanService.startHost`). |
| `lanConnect` | Connect as guest to host IP + port + peer id. |
| `lanSend` | Send a JSON message to a peer id. |
| `lanClose` | Close the guest client socket. |
| `lanStopHost` | Stop the local relay. |
| `lanGetIp` | Return the host device's local IP. |

Dart → JS uses two narrow `CustomEvent`s only: `dsLanMessage` (`{from, data}`) and `dsLanPeerLeft` (`{from}`), dispatched into the WebView — never arbitrary script evaluation. The WebView origin remains `http://localhost:8080`; there is no generic "open arbitrary socket" or "fetch arbitrary URL" bridge.

The mobile shim in `bridge.dart` defines `window.dsLan` with `host`, `connect`, `send`, `close`, `stopHost`, and `ip`. In a hosted browser `window.dsLan` is **undefined** and LAN mode shows an "Android only" toast. `buildMobileShim` also guards against overwriting `window.__dsLanMode`, so the LAN hint is preserved.

### 4.3 Web game LAN adapter — `assets/web/index.html`

**Status: Implemented.**

- Explicit mode selector: **أونلاين** (online, default, unchanged) / **شبكة محلية** (LAN) / **بوتات** (bots).
- `LanPeer` / `LanConn` are PeerJS-compatible shims implementing the small API the game uses (open/close, data, send, error). `LanConn` serialises `window.dsLan.send(...)`; `dsLanMessage` / `dsLanPeerLeft` feed the existing game handlers.
- Host flow: `window.dsLan.host(8974)` then the host connects locally to `127.0.0.1`.
- Joiner flow: enter the host's local IP and the room code.
- Lobby shows `طاولة محلية — ... IP: <ip> والكود <code>`; the public share button is hidden in LAN mode and only the code is copied.
- The LAN hint is no longer overwritten by the shim.

---

## 5. Network and platform considerations

- `INTERNET` is already declared; local sockets add no new permission for this design.
- `network_security_config.xml` allows cleartext only for `localhost` / `127.0.0.1`. A raw Dart TCP socket is not a WebView HTTP request, so it is not governed by that rule. No cleartext widening was introduced.
- **Hotspot AP/client isolation** can block device-to-device traffic even with correct code. A real two-phone test must use a hotspot with isolation disabled or a normal shared Wi-Fi network.
- On the emulator, `localIp()` returned the emulator NAT address `10.0.2.16`, not a LAN address. That is a single-device artifact; it is not evidence of real hotspot behaviour.
- No traffic to PeerJS Cloud or public STUN is made in LAN mode by design (`LanPeer` replaces PeerJS, and the shim does not create a PeerJS instance). A network-capture confirmation is still **Not tested**.

---

## 6. What was implemented (checklist)

1. **Bridge contract:** token-validated `lan*` handlers and two narrow `CustomEvent`s — done.
2. **Dart relay/client:** `LanService` with newline-delimited JSON, `register`/`relay`/`peerleft`/`error` — done; unit tests added.
3. **Web adapter:** `LanPeer`/`LanConn` shim plus explicit mode selector — done.
4. **Mode guard:** hosted browser has no `dsLan`; LAN mode shows "Android only" — done (code inspection), no network-capture test.
5. **Device tests:** single-device emulator smoke passed (see §7). Real two-device hotspot — **Not tested**.
6. **Regression:** `flutter analyze` clean; `flutter test` 12/12 pass — done.

---

## 7. Test evidence

| Test | Environment | Result | Status |
|---|---|---|---|
| `flutter analyze` | Local checkout | Clean | Tested successfully |
| `flutter test` (12/12, incl. 2 new `lan_service_test.dart` tests) | Local checkout | Pass | Tested successfully |
| Two-client `register` + `relay` routes messages | `lan_service_test.dart` (unit, loopback) | Pass | Tested successfully (unit) |
| Unknown peer → `error`, no crash | `lan_service_test.dart` (unit) | Pass | Tested successfully (unit) |
| LAN mode selected, local room created, lobby shows IP + code | Emulator `emulator-5554` | Lobby displayed `طاولة محلية — ... IP: 10.0.2.16 والكود 3CWHV` | **Tested with limitations** (emulator NAT IP, one device) |
| No PeerJS Cloud / STUN traffic during LAN mode | Network capture / firewall | Not captured | Not tested |
| Two real phones, hotspot with no internet, AP isolation off | Physical devices | Not run — no devices attached | **Not tested** |
| 3–5 players, host-left / reconnect / migration in LAN | Physical devices | Not run | Not tested |
| Chat and voice behaviour over LAN end-to-end | Two devices | Not run | Not tested |

See `PHASE5_FEATURE_REPORT.md` for the consolidated per-test evidence and the emulator-vs-physical-device split.

---

## 8. Limitations and blockers

- **Offline LAN Android↔Android:** transport is implemented, unit-tested, and single-device smoke-tested. Two-device offline play is **Not tested**; the core scenario is unverified.
- **Offline Web↔Web and Android↔Web are unsupported by this design.** A browser cannot host the Dart TCP relay (no local server on the static host, no secure-context browser TCP server), and the mobile-only `dsLan` shim is absent in a hosted browser. Do not plan on these pairs.
- **No QR code.** Easy joining is implemented as local IP + room code shown in the lobby. QR generation is a documented future enhancement only.
- Relay-side rate limiting, message size caps, heartbeats, and max-peer count remain future hardening; they are not claimed.
- Wi-Fi Direct is a possible alternative but changes connectivity assumptions; it is not part of this implementation.
- Moderation, Play upload, and release approval are separate blockers and are unaffected by LAN work.
- No hosting, upload, or non-documentation source change was made for this document.

---

## 9. Related documents

- `NETWORK_COMPATIBILITY_MATRIX.md` — implemented/tested/blocked status by device pair.
- `PHASE5_FEATURE_REPORT.md` — consolidated test evidence, emulator vs physical device.
- `WEB_DEPLOYMENT_GUIDE.md` — public host constraints; LAN must work without it.
- `CHAT_IMPROVEMENT_PROPOSALS.md` — chat/voice behaviour LAN mode must preserve.
- `PROJECT_AUDIT_AND_NEXT_STEPS.md` — Phase 0 findings and developer decision approving native LAN signalling.
