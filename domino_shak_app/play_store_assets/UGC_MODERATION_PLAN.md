# UGC moderation plan — local controls shipped, backend still a plan

App: **دومينو شك / Domino Shak** · Date: 2026-11-18
Status: the **local** client controls (terms gate, anonymous pid, block/filter, report outbox) are implemented and tested in the mobile copy. The **backend** described below is a proposal only. Not legal advice. No accounts, services, or deployments were created for this plan.

> **STOP: no backend accounts, deployments, domains, or paid services created; requires explicit user approval before any of that.**

For a research-only comparison of concrete backend options (architecture, blocklist, review, appeals, hosting, free-tier limits/costs, and security/privacy), plus an assessment of Google Play Child Safety Standards applicability, see `MODERATION_BACKEND_COMPARISON.md`.

## 0. What is actually shipped today

Verified in `test_evidence/ugc_single.json` (on-device) and `test_evidence/ugc_cross.json` (cross-peer protocol):

- Community-terms gate before room create/join/chat, with a published prohibited-behavior list.
- Stable random `dmnshk-pid` propagated through join/welcome/state/snap/chat.
- Report dialog on seats and received messages: reason → local outbox (`dmnshk-reports`) with room, pid, and snippet. Copy/share is user-initiated.
- Block/filter: `dmnshk-block` hides a pid's past and future messages/voice before they reach the chat list or unread badge. Unblock from Settings.
- In-app privacy policy with an Android-back hook and home/Settings links.

Everything in §3.4 and later (intake endpoint, signed blocklist, reviewer queue, appeals, contact) is **not** implemented. The local outbox is evidence on the reporter's device, not moderation.

## 1. Why a local-only report button is not real moderation (release blocker)

The app has free-text chat, quick phrases/emoji, player-chosen names, and 30-second voice messages sent peer-to-peer. A button that only writes a report to the device's `localStorage` has no review, no enforcement across devices, and no appeal. Google Play treats apps with user-generated content (UGC) as needing reporting, blocking, a published content policy, and a way to moderate content. Therefore:

| Gap | What a local-only report does | Why it fails |
| --- | --- | --- |
| Intake | Saves a note on the reporter's device | No reviewer ever sees it; deleting app data deletes the evidence |
| Enforcement | Local blocklist hides a peer ID on one device | Reported user keeps interacting with everyone else; peer IDs are random per session, so a new ID evades the block |
| Policy | No published prohibited-behavior rules | Users and reviewers have no standard to apply |
| Triage/action | Nothing | No decision, no audit trail, no consistent outcome |
| Appeals | Nothing | No way to contest a wrong action |
| Duties | No developer-owned contact | No legal/privacy contact for reports or requests |

**Conclusion:** do not submit to Play while UGC reporting/blocking/moderation is unresolved. Local controls can improve the client, but they do not satisfy the UGC requirement by themselves.

## 2. Prohibited behavior policy / سياسة المحتوى الممنوع

Applies to display names, chat text, quick phrases/emoji used as harassment, and voice messages.

| Category (EN) | الفئة (AR) | Rule / القاعدة |
| --- | --- | --- |
| Harassment | التحرش والمضايقة | No bullying, targeted insults, repeated unwanted contact, or intimidation. / لا تنمّر ولا إهانات متكررة ولا ملاحقة. |
| Hate | الكراهية | No content attacking people based on religion, ethnicity, nationality, race, gender, disability, or similar traits. / لا تحريض ولا احتقار على أساس الهوية. |
| Threats | التهديدات | No threats of violence, harm, or coercion. / لا تهديد بالعنف أو الأذى. |
| Sexual content | المحتوى الجنسي | No sexual content, solicitations, or explicit material, including in voice. / لا محتوى جنسي صريح ولا عروض جنسية. |
| Personal info / doxxing | البيانات الشخصية والتسريب | No publishing real names, addresses, phone numbers, emails, social handles, or other people's private information. / لا نشر بيانات خاصة لأي شخص. |
| Spam | الرسائل المزعجة | No flooding, repetitive ads, link spam, or disruption of the game. / لا إغراق ولا إعلانات ولا روابط مزعجة. |
| Impersonation | الانتحال | No pretending to be another player, the developer, or an official entity. / لا انتحال شخصية لاعب أو للمطوّر. |
| Illegal content | المحتوى غير القانوني | No content facilitating illegal activity or violating applicable law. / لا محتوى يساعد على نشاط غير قانوني. |
| Voice abuse | إساءة استخدام الصوت | No shouted abuse, threatening speech, or sexual speech in voice messages; no using voice to bypass text rules. / لا شتائم أو تهديدات أو محتوى جنسي بالصوت. |

Enforcement scale (suggested, to be confirmed before use): warning → temporary block → longer block → removal/escalation for severe cases (threats, doxxing, illegal content).

## 3. Simplest architecture that could satisfy the requirement — without accounts

No login, no email, no password, no user database. Identity is a **random per-install ID** and a **random per-session peer ID**, both stored only on the device (the install ID rotatable).

```text
Player app (WebView)  --HTTPS-->  minimal report intake endpoint
Player app (WebView)  --HTTPS-->  signed blocklist JSON (cached on device)
Developer reviewer   --private--> manual review queue / local admin file
```

### 3.1 Components

| Component | Responsibility | Notes |
| --- | --- | --- |
| In-app terms gate | Show the policy above; record acceptance locally | Implementable now, local only |
| In-app report form | Reason category + optional short text snippet + report ID | Send to intake endpoint only after backend exists; until then, local outbox/export |
| In-app block/mute | Hide or mute a reported peer ID locally | Immediate self-protection; not a ban |
| Report intake endpoint | Accept small JSON, rate-limit, reject abuse, write to private store | HTTPS required; no accounts |
| Manual review queue | Private list of reports with statuses and notes | Human decisions only; no automatic bans from raw reports |
| Blocklist publisher | Produce versioned JSON with actions and an Ed25519 signature | Clients verify signature with a public key pinned in the app |
| Developer contact | Receive appeals and legal/privacy requests | Must be owned by the developer; not invented |

### 3.2 Minimal report record (no accounts)

| Field | Purpose | Privacy note |
| --- | --- | --- |
| `report_id` | Deduplication and audit trail | Random UUID |
| `room_code` | Context for the reviewer | Short-lived, typed by users; do not treat as identity |
| `reporter_pid` | Identify the reporting session | Random peer/session ID, rotatable |
| `reported_pid` | Identify the reported session | Random peer/session ID; evasion possible after rotation |
| `reason` | Category from the policy table (enum) | No free text required |
| `snippet_hash` / `snippet` | Optional short evidence: up to ~200 chars of text, or SHA-256 + duration for voice | Do **not** upload voice audio by default; if audio evidence is ever added, it needs explicit consent, storage limits, and a policy update |
| `timestamp` | Triage order and retention | UTC |

Optional `install_id` (random, per install) may be included to make blocks slightly more durable; it still is not an account and can be rotated or lost on reinstall. **Honest limitation:** without accounts, durable bans are unreliable; a determined offender can return with new IDs. This must be disclosed in the moderation policy, not hidden.

### 3.3 Signed blocklist

Versioned JSON fetched by the client over HTTPS, verified with a pinned public key:

| Field | Meaning |
| --- | --- |
| `version` | Monotonic version number |
| `generated_at` | UTC timestamp |
| `entries[]` | `{ key_type: "pid" | "install_id_hash", key: "...", action: "block" | "mute", expires_at, reason_code }` |
| `signature` | Ed25519 signature over the canonical JSON body |

Client behavior on fetch failure or bad signature: keep the last valid list, fail closed for newly reported peers, and never accept an unsigned list. Because peer IDs rotate, entries should have expiry times and be pruned; never build a permanent identity graph.

### 3.4 What is still required outside the app

- A **hosting provider** for the intake endpoint and blocklist file (serverless function or small server).
- A **domain** with HTTPS for stable endpoints.
- A **developer-owned contact/email** for reports, appeals, and privacy requests.
- A named **reviewer** (the developer or a trusted person) and written internal procedures.
- Updates to the privacy policy, Data Safety form, and UGC disclosure before the backend build ships.

## 4. Practical moderation workflow

| Stage | Action | Owner | Suggested target (not a promise) | Output |
| --- | --- | --- | --- | --- |
| 1. Intake | Client sends one report; endpoint validates size, rate-limits, assigns `report_id`, stores it privately | Automated intake | Immediate | Queued report |
| 2. Triage | Reviewer reads reason + snippet, groups by `reported_pid`/`room_code`, checks duplicates | Reviewer | Same/next day | `new` → `in_review` → decision |
| 3. Action | Decide: no action, warning, temporary mute/block, long block, or escalation for threats/doxxing/illegal content | Reviewer | ~1–3 days | Decision + note + expiry |
| 4. Blocklist publish | Regenerate versioned, signed JSON; app fetches on launch/periodically | Reviewer/automated publish | After decision | New `version` live |
| 5. Appeals | Developer-owned contact receives appeal; reviewer re-checks evidence, can revert or uphold, keeps audit note | Reviewer | Defined, published window | `appealed` → `upheld`/`reverted` |
| 6. Retention | Delete/expire reports and blocklist entries per policy | Reviewer/automated cleanup | See §6 | Minimal retained data |

Statuses for the queue: `new`, `in_review`, `actioned`, `rejected`, `appealed`, `upheld`, `reverted`, `closed`.

## 5. In-app controls: now vs backend-required

| Control | Status in this build | Needs backend |
| --- | --- | --- |
| Terms acceptance gate (Arabic + English policy text) | **Shipped** — `dmnshk-terms-v1` in `localStorage` | No |
| Local blocklist / mute by peer ID | **Shipped** — `dmnshk-block`, hides past and future messages | No (but weak without shared list) |
| Report form UI with reason categories | **Shipped** — collects reason + snippet locally | Yes, to actually submit |
| Local report outbox / export (user-initiated) | **Shipped** — `dmnshk-reports`, copy/share button | No |
| Automatic upload of reports | Not implemented | **Yes** — intake endpoint |
| Cross-user enforcement / ban | Not implemented | **Yes** — signed blocklist distribution |
| Manual review and appeals | Not implemented | **Yes** — reviewer queue, contact channel |
| Privacy policy + Data Safety update for collected reports | In-app policy shipped; Data Safety draft updated for local data | **Yes** — required before backend build ships |

The shipped local controls improve user safety but do **not** resolve the Play UGC release blocker.

## 6. Privacy and legal notes for the proposed backend

| Topic | Note |
| --- | --- |
| What the backend would see | Report ID, room code, reporter PID, reported PID, reason, optional short snippet/hash, timestamp, plus the HTTP request IP address and user agent from the connection. No chat history, no voice audio by default, no location, no contacts. |
| IP addresses | Servers necessarily see request IPs; disclose in the privacy policy and Data Safety form, apply short retention, and avoid permanent IP logs where possible. |
| Retention suggestions | Reports: 30–90 days, then delete unless needed for an active appeal or legal hold. Blocklist entries: expire automatically (hours to days for routine cases). Audit notes: minimal and time-limited. These are starting points, not legal requirements. |
| Security | HTTPS only, authentication for the reviewer interface, rate limiting, input size caps, no public report listing, restricted access, backups encrypted or avoided. |
| Contact/legal | A developer-owned email/site must be published for reports, appeals, privacy requests, and illegal-content escalation. Consider applicable data-protection obligations if users are in jurisdictions with such laws; define who the reviewer is and what lawful basis/notice applies. |
| Data Safety impact | Adding the backend changes "no developer-collected data": report records become collected data with a safety/moderation purpose, a retention period, and a deletion path. Update all disclosures before that build is submitted. |
| Third-party policies | Hosting/CDN providers have their own terms and privacy policies; review them before choosing any provider. No provider has been selected here. |

## 7. Cost options — ranges only, no commitment

| Option | Illustrative cost | Trade-offs |
| --- | --- | --- |
| Free tier (serverless function + static file hosting) | US$0/month within quotas | Quota/abuse limits, vendor terms, possible cold starts, and data-location questions; verify before any use |
| Low-cost VPS + static blocklist | Roughly US$3–10/month | More control and predictable behavior; requires server maintenance, patching, backups, and secure configuration |
| Domain + HTTPS | Domain roughly US$10–20/year; TLS certificates often free (e.g., Let's Encrypt) | Needed for stable endpoints; registration details must be developer-owned |
| Developer contact mailbox | Often free, otherwise a few US$/month | Must be controlled by the developer; do not use a made-up address |

These are broad, illustrative ranges, not quotes or recommendations. **No signup, trial, deployment, domain registration, or payment has been made.**

## 8. Decision gate / approvals needed

| Decision | Required before proceeding | Status |
| --- | --- | --- |
| Accept this policy text and enforcement scale | Developer sign-off | Open |
| Choose local-only interim UX vs full backend | Explicit developer decision | Open |
| Hosting provider, domain, reviewer identity, contact email | Explicit developer approval; **no accounts or purchases without it** | Open |
| Choose retention windows and appeal process | Developer/legal review | Open |
| Update privacy policy + Data Safety + content rating | Must happen before any backend build is submitted | Open |
| Two-device tests of reporting/blocklist flow | Needed after implementation | Open |

**STOP: no backend accounts, deployments, domains, or paid services created; requires explicit user approval before any of that.**

## 9. Assumptions and open questions

- Assumed the current app has no accounts, no developer backend, no analytics/ads/crash reporting, and STUN-only WebRTC with PeerJS public signaling (per `PRIVACY_AND_DATA_SAFETY.md`, `PHASE4_REPORT.md`, `REAL_DEVICE_TEST_REPORT.md`).
- UGC terms acceptance, local blocklist, and report outbox are shipped in the **mobile copy only**; the original website `../index.html` is unchanged. They were verified on-device and across two same-code browser peers.
- Real microphone capture was not verified on test devices (synthetic audio only); the voice policy still applies because the feature exists.
- Open: will Play accept a no-account, human-reviewed, signed-blocklist approach for this app, or will it require stronger identity/enforcement? Needs confirmation against the current Play Console UGC declaration before release.
- Open: who is the reviewer, what contact will be published, and which jurisdiction's rules apply — all developer input, none invented here.
