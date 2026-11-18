# Moderation backend options — research and cost comparison (review only)

App: **دومينو شك / Domino Shak** · Date: 2026-11-18
Status: **research/documentation only.** No accounts, services, domains, purchases, deployments, AAB changes, or Play Console actions were made. Prices and policies are snapshots checked on 2026-11-18; verify before any commitment. This is not legal advice.

> **STOP: nothing here is approved for implementation or deployment.** Choosing an option, creating an account, registering a domain, deploying code, or modifying the AAB requires separate explicit approval.

---

## Part A — What Google Play actually requires (official sources)

### A.1 User Generated Content (UGC) policy
Source: <https://support.google.com/googleplay/android-developer/answer/9876937?hl=en>
Explainer: <https://support.google.com/googleplay/android-developer/answer/12923286?hl=en>

Domino Shak has free-text chat, quick phrases/emoji, player-chosen names, and 30-second voice messages exchanged between players. That is UGC "visible to or accessible by at least a subset of the app's users." Play requires **robust, effective, and ongoing moderation**:

1. **Terms acceptance before UGC creation** — cannot be skippable. (Shipped locally: `dmnshk-terms-v1`.)
2. **Defined objectionable content/behaviour** in those terms. (Shipped locally: policy table in `UGC_MODERATION_PLAN.md §2`.)
3. **In-app reporting and blocking.** Because chat/voice are **1:1 interactions with specific users**, an **in-app block function is explicitly required**. (Report dialog and local block/filter shipped, but reports never leave the device.)
4. **Action on reports in a timely manner** — the explainer says developers "should always make sure that appropriate actions are taken on reported users or content in a timely manner." A local outbox with no reviewer does not meet this.
5. **Accurate content-rating questionnaire answers about UGC.**

Play also lists as a common violation: "Apps with user generated content (UGC) that lack sufficient safeguards against threats, harassment, or bullying, **particularly toward minors**," and "apps that continually fail to address user complaints."

**Key point for this app:** the policy does not demand a particular backend technology. It demands a functioning loop: report → review → action → (log). A human-reviewed, no-account backend can satisfy it if reports actually arrive and action is actually taken. The exact acceptance of the proposed signed-blocklist design still has to be confirmed against the Play Console UGC declaration at submission time.

### A.2 Child Safety Standards (CSS)
Sources:
- <https://support.google.com/googleplay/android-developer/answer/14747720?hl=en> (scope + FAQ)
- <https://support.google.com/googleplay/android-developer/answer/14585136?hl=en> (full policy)
- <https://support.google.com/googleplay/android-developer/answer/9878809?hl=en> (Child Endangerment + CSS requirements)
- <https://support.google.com/googleplay/android-developer/table/12921780?hl=en> (deadlines)

**In scope today:** "Anonymous and Random chat apps, and apps in the Social and Dating categories." Play's definitions:

| Category | Play's definition |
| --- | --- |
| Anonymous chat | "core functionality is for users to communicate anonymously where the identity of one or more users is deliberately hidden" |
| Random chat | "core functionality is to facilitate randomly connecting users to spontaneously communicate with people they do not know" |
| Social | app **declares itself** as Social in Play Console |
| Dating | app **declares itself** as Dating in Play Console |

**"But it's not for kids / adults only / age-gated" does not help.** The FAQ is explicit: "The presence or absence of child users in your app is irrelevant to this policy. If your app meets the criteria above, then it is within the scope of this policy and must comply with its requirements."

**Five CSS requirements** (self-certified in Play Console):

1. **Published standards against CSAE** — a globally accessible web resource that loads without error, mentions CSAE/child safety, and **references the app or developer name**. Link supplied in Console. (A dedicated page on the already-live GitHub Pages site would satisfy this; adding it requires approval.)
2. **In-app mechanism for user feedback** — Play's FAQ says this can be "a comprehensive in-app user feedback experience, a support email, or chat channel for reports," as long as the user can access it **without leaving the app**. The shipped in-app report dialog + policy links are a plausible basis, but must be certified in Console.
3. **Address CSAM** — self-certify appropriate action (including removal) after obtaining **actual knowledge**, per published standards and law.
4. **Comply with child safety laws** — including a process to report confirmed CSAM to **NCMEC** (<https://report.cybertip.org/>) or the relevant regional authority.
5. **Designated child-safety point of contact** — a named individual with contact details, ready to speak to enforcement/review procedures. Developer input required; none invented here.

### A.3 Deadlines — already in effect
The Policy Deadlines table shows **2026-08-26** (now past, given today's date 2026-11-18) expansions:

- **Child Endangerment** → Child Safety Standards expanded to **anonymous chat and random chat apps**.
- **Google Play Families** → expanded to prohibit developers of **anonymous chat apps from targeting children**.
- **Age-Restricted Content and Functionality** → expanded to anonymous/random chat apps.

The Age-Restricted policy (<https://support.google.com/googleplay/android-developer/answer/16302250?hl=en>) now explicitly lists apps whose core functionality is:
- "randomly connecting users to spontaneously communicate with people they do not know"; or
- "users to communicate anonymously where the identity of one or more users is deliberately hidden"

— and requires Play Console tools to block minors.

Also note **2026-09-30**: Android developer verification / Play Console registration of apps. Developer-side task; past deadline.

### A.4 Families policy
<https://play.google.com/about/families/children-and-families/>
If the app is not declared as targeting children, Families design/ads/SDK rules are less restrictive, but the 2026-08-26 change prohibits anonymous-chat apps from targeting children. Declaring "not for children" does **not** remove CSS scope (see A.2).

---

## Part B — Does Domino Shak trigger the Child Safety Standards?

### B.1 The anonymous player ID alone
The `dmnshk-pid` is a random per-install/session identifier. Play's "anonymous chat" definition is about **core functionality** and **deliberately hidden user identity**, not about whether an app stores an internal random ID. Almost every app has internal identifiers. Therefore:

- A random `dmnshk-pid` **by itself does not make Domino Shak an "anonymous chat app."**
- Players choose visible nicknames, and rooms are joined by a **shared room code**, not by random matching. That argues **against** the literal "random chat" and "deliberately hidden identity" definitions.

### B.2 The P2P chat/voice with strangers
This is the stronger trigger:

- Play's concern is CSAE/CSAM risk in **1:1 communication between people who do not know each other**, including voice. Room codes connect strangers; chat and 30-second voice messages are person-to-person.
- The expanded Age-Restricted policy targets exactly "spontaneously communicate with people they do not know."
- If the Play Console category is ever set to **Social** (or Dating), CSS applies **automatically by declaration**, regardless of the app's actual mechanics.
- Play reviewers assess the **listing and in-app experience** (screenshots include a chat screen).

### B.3 Conclusion (risk assessment, not a legal determination)
| Question | Assessment |
| --- | --- |
| UGC moderation requirements apply? | **Yes, definitively.** Free-text chat, names, emoji, voice. Not contingent on category. |
| Child Safety Standards apply? | **Likely / arguable, and should be planned for as if yes.** The literal "anonymous chat" and "random chat" definitions are debatable for a room-code game with nicknames, but the 2026-08-26 expansion targets stranger communication, the app has 1:1 chat + voice with strangers, and a Social category declaration would make it automatic. |
| Does "adults only" or age-gating avoid it? | **No.** Play says user age is irrelevant to scope. |
| What to do? | **Comply with CSS regardless of whether it is strictly required.** The marginal work is: a public CSAE standards page, an in-app feedback path (already largely present), a CSAM action/removal + NCMEC reporting procedure, and a named point of contact. These overlap heavily with the UGC moderation work, so treating CSS as in-scope is the low-risk path. |

**Practical implication:** the moderation backend must support **escalation and evidence preservation for CSAE/CSAM reports**, not just generic spam/harassment. A report reason such as "child safety / exploitation" should route to a priority queue with a documented removal + authority-reporting procedure. Do not upload voice audio by default; if CSAE evidence requires it, that needs explicit consent, a policy update, and strict retention.

---

## Part C — Options, each against the seven requested dimensions

All options assume the **existing local client controls remain** (terms gate, block/mute, report dialog). What changes is what happens **after** the user taps Report.

### Common minimum data model (applies to every backend)
`report_id`, `room_code`, `reporter_pid`, `reported_pid`, `reason` (enum, incl. a child-safety category), optional short `snippet` (≈200 chars) or `snippet_hash`, `timestamp`. No chat history, no voice audio by default, no accounts, no email, no location, no contacts. HTTP request IP is necessarily visible to the host and must be disclosed and short-lived. Because IDs rotate, durable bans are unreliable — disclose this honestly.

---

### Option 0 — Local-only (status quo) — **non-compliant baseline**

1. **Architecture / report flow:** Report writes to `localStorage` (`dmnshk-reports`). No network. User may copy/share manually.
2. **Central blocklist:** None. Each device has its own `dmnshk-block`.
3. **Moderator review / action:** None. No reviewer, no decision, no audit trail.
4. **Appeals:** None.
5. **Hosting / domain:** None.
6. **Cost:** $0.
7. **Security / privacy:** Best possible data minimisation — nothing leaves the device. **But** evidence is lost on uninstall, and there is no enforcement.
   **Verdict:** does not satisfy Play UGC policy. Not a release option.

---

### Option 1 — Cloudflare Workers + D1/KV + R2 (+ Turnstile) — **recommended for review**

1. **Architecture / report flow:** A Worker at a fixed HTTPS path accepts `POST /report`, validates JSON size/schema, applies per-IP/per-pid rate limiting (D1/KV counters), optionally checks Turnstile, assigns a UUID, and writes the record to D1 (or KV). Reviewer actions write to a `blocklist` table. A second Worker serves `GET /blocklist/v1.json` (signed JSON) with edge caching. Reporting from the WebView is an `https://` subresource request from `http://localhost:8080` — an http→https upgrade (allowed), but **CORS must explicitly allow origin `http://localhost:8080`**. Top-level navigation allow-list is unaffected (`shouldOverrideUrlLoading` does not normally intercept `fetch`).
2. **Central blocklist:** Versioned, Ed25519-signed JSON served from KV or D1 at a stable URL. Fields: `version`, `generated_at`, `entries[{key_type, key, action, expires_at, reason_code}]`, `signature`. Clients pin the public key in the app, reject bad/unsigned lists, keep the last valid list on failure, and expire entries automatically.
3. **Moderator review / action:** Private admin route (or a simple CLI/script using the D1 API) listing reports by status. Reviewer sets `new → in_review → actioned/rejected`; actions are warning / temporary mute / block / escalation. Severity (threat, doxxing, illegal, CSAE) can auto-flag priority. Publishing the signed list is a separate explicit step.
4. **Appeals:** In-app appeal form posts `type=appeal` with the enforcement `action_id`/token shown on the block screen; reviewer re-checks, sets `appealed → upheld/reverted`, and the next blocklist version carries the reversal. Because there is no account/email, the client must check appeal status by token on launch; if no token is kept, notification is impossible — disclose.
5. **Hosting / domain:** **No custom domain required** — `*.workers.dev` gives free HTTPS. A developer-owned domain is optional (≈$10–20/yr registration; TLS free). Turnstile is free with unlimited challenges (10 hostnames/widget). The existing GitHub Pages site can hold the CSAE standards page at no extra cost.
6. **Free-tier limits / cost:** Workers Free **100,000 requests/day**, 10 ms CPU/request; KV **100k reads/day, 1k writes/day, 1 GB**; D1 **5M rows read/day, 100k rows written/day, 5 GB total** (500 MB per DB); R2 **10 GB-month, 1M Class A / 10M Class B ops/month, free egress**. For a small game this is comfortably **$0/month**. Paid: **$5/month minimum per account** (10M requests, 30M CPU-ms included); overages $0.30/1M requests, $0.02/1M CPU-ms; D1 beyond included $1/1M rows written, $0.75/GB-mo. **Risk:** KV writes (1k/day) are the first wall if used for per-request rate limits; unindexed D1 scans consume rows read fast — index `reported_pid`, `status`, `created_at`.
7. **Security / privacy:** HTTPS + HSTS by default; no server to patch; Turnstile and IP throttling blunt abuse; D1/KV are private by default (no public report listing). Reviewer access needs a separate credential (a second Worker route behind an admin token, or Cloudflare Access). Caveats: Cloudflare sees request IPs and content; data location/legal process questions must be reviewed; a misconfigured public KV namespace would leak reports; the signing private key must never be stored where the reporting Worker can read it (sign offline or keep the key in a separate Worker secret).

---

### Option 2 — Supabase (managed Postgres)

1. **Architecture / report flow:** Client `POST`s to a Supabase Edge Function (validation, rate limiting, insert into `reports`). Reviewer uses the Supabase table editor or a small internal UI. A second function or a Storage object serves the signed blocklist.
2. **Central blocklist:** A `blocklist_entries` table plus a `blocklist_published` view; Row Level Security (RLS) permits **anonymous SELECT only** on the published view/JSON. A privileged function signs the canonical JSON with the private key and writes the result to a public-read Storage object.
3. **Moderator review / action:** Table rows with statuses and notes; Supabase Auth for the reviewer account; optional lightweight admin UI. Actions update rows; a "publish" function bumps `version` and re-signs.
4. **Appeals:** `appeals` table keyed by `action_id`; same reviewer workflow; reversal written to the next signed list.
5. **Hosting / domain:** `<ref>.supabase.co` HTTPS included; **no custom domain needed**. Custom domain optional (typically a Pro feature).
6. **Free-tier limits / cost:** Free **$0**: 500 MB DB, 50k MAU, 5 GB egress, 1 GB file storage, 500k Edge Function invocations, 2 active projects, **paused after 1 week of inactivity**, no automatic backups, 1-day logs. Pro **from $25/month**: 8 GB disk/project, 100k MAU, 250 GB egress, daily backups (7 days), never paused; extra projects from ~$10/mo. **Verdict:** Free is fine for testing but **pausing + no backups make it a poor production choice** for a safety system. Budget **~$25/month** if used in production.
7. **Security / privacy:** Mature RLS — but RLS misconfiguration is the classic leak; the anon key must never be treated as a secret; the signing key belongs in Edge Function secrets, not the client. Backups on Free are absent (audit trail loss risk). US/EU region choice affects data-protection analysis. Reviewer account needs MFA.

---

### Option 3 — Firebase (Firestore + Cloud Functions; Hosting optional)

1. **Architecture / report flow:** A Cloud Function (HTTPS endpoint) validates and writes a `reports/{id}` document; an admin Function/CLI publishes the blocklist. Firestore Security Rules expose only the single `blocklist/current` document to unauthenticated reads.
2. **Central blocklist:** `blocklist/current` document containing the pre-signed JSON; rules allow public read of that document only. Clients verify the Ed25519 signature locally.
3. **Moderator review / action:** Firebase Console firestore editor or a small admin page; reviewer updates `status`; an "on update" function re-signs and bumps `version`.
4. **Appeals:** `appeals/{token}` documents; reversal reflected in next blocklist version.
5. **Hosting / domain:** `*.web.app` / `*.firebaseapp.com` HTTPS free; **no custom domain needed**.
6. **Free-tier limits / cost:** **Spark $0** (no card): Firestore 1 GiB stored, **50k reads/day, 20k writes/day**, 10 GiB egress/month, Hosting 10 GB + 360 MB/day — but **Cloud Functions and Cloud Storage are NOT available on Spark**. A real intake endpoint needs Functions, so this option effectively requires **Blaze** (payment method). Blaze keeps the same free quotas, then ~$0.03/100k reads, ~$0.09/100k writes (us-central1), ~$0.15/GiB-mo; Functions 2M invocations/month free, then $0.40/M, plus CPU/GB-seconds. Likely **$0–$10/month** at small volume, but **no hard spend cap** (budget alerts only; Firestore cannot be auto-paused by a budget). $300 new-account credit may apply.
7. **Security / privacy:** Security Rules are powerful but easy to get wrong; Cloud Functions on Blaze needs careful IAM and secret handling. App Check could attest requests, but adding an SDK to the bundled WebView app is extra work. Firebase/Google sees IPs and content. Blaze's uncapped spend is a genuine operational risk. Locking rules to a single public document is essential.

---

### Option 4 — Appwrite Cloud (or self-hosted Appwrite)

1. **Architecture / report flow:** Appwrite Function accepts reports and writes to a `reports` collection; reviewer uses Appwrite Console or a custom UI.
2. **Central blocklist:** A `blocklist_entries` collection with a public-read document/view, or a signed JSON file in Appwrite Storage.
3. **Moderator review / action:** Document statuses + notes; Appwrite Auth for reviewer; a publish function signs and version-bumps.
4. **Appeals:** `appeals` collection keyed by token; reversal in next list.
5. **Hosting / domain:** Appwrite Cloud endpoint is HTTPS; **no custom domain needed**. Self-hosting is free software but needs Docker + ≈2 CPU/4 GB RAM (≈$24/month droplet) and a domain for trusted TLS.
6. **Free-tier limits / cost:** Free **$0**: 2 projects, 75k MAU, 500k DB reads / 250k writes per month (some plan pages list 750k function executions), 2 GB storage, 5 GB bandwidth, **paused after 1 week inactivity**. Pro **$25/month/project** (+~$15 extra projects): 200k MAU, 1.75M reads / 750k writes, 150 GB storage, 2 TB bandwidth, daily backups (7 days), $10 database compute credit. Overages $3/1k users, $0.06/100k reads, $0.10/100k writes. Self-host: software $0 + server/ops.
7. **Security / privacy:** Open source (BSD-3), self-host option avoids vendor data access; Cloud has budget caps (good). Same pausing/no-backup-on-Free caveat as Supabase. API keys and collection permissions must be scoped carefully; reviewer account needs MFA. Smaller ecosystem than Firebase/Supabase.

---

### Option 5 — PocketBase (or a small custom service) on a low-cost VPS — self-hosted

1. **Architecture / report flow:** Single Go binary with embedded SQLite + admin UI. A small HTTP hook (JS/Go) validates incoming reports, rate-limits, and inserts into a `reports` collection. Reviewer uses the built-in admin dashboard — **no separate admin app to build**.
2. **Central blocklist:** A `blocklist_entries` collection; a scheduled hook or script writes a versioned, signed JSON file served as a static route.
3. **Moderator review / action:** Built-in admin UI with status fields and filters; publish action regenerates the signed file.
4. **Appeals:** `appeals` collection; reversal in next signed list.
5. **Hosting / domain:** Requires a **VPS** and, for trusted public TLS, **a domain or free DDNS name** (Let's Encrypt needs a hostname). **This is the only option where a domain is effectively required** for a clean HTTPS setup (a bare IP cannot get a normal public certificate). Caddy can automate TLS.
6. **Free-tier limits / cost:** Software **free (MIT)**. VPS examples checked 2026-11-18: **Hetzner CX23 ~€5.49/mo + €0.50 IPv4 (~$7/mo, 2 vCPU/4 GB, 20 TB EU traffic; EU-only)**; **Vultr $3.50–$5/mo** (0.5–1 GB); **DigitalOcean $4–$6/mo** entry. Add ~20% for backups, domain ~$10–20/yr. **~$7–12/month all-in.** You trade money for full control and no per-request quotas.
7. **Security / privacy:** Full control over data location and retention; no third-party processor with report contents. But you own **OS patching, firewall, TLS renewal, backups, restore testing, monitoring, and log hygiene** — a missed backup or an unpatched box is a real risk. PocketBase is a volunteer project: pre-1.0 compatibility is not guaranteed, and it scales on a single server only (fine at this app's size). Signing key lives on the box — protect it.

---

### Option 6 — GitHub Issues + GitHub Pages (low-cost but not recommended)

1. **Architecture / report flow:** A form or script files a GitHub Issue per report in a private repo. No server-side validation or abuse throttling beyond GitHub's own limits.
2. **Central blocklist:** A signed JSON file committed to a repo and served via GitHub Pages.
3. **Moderator review / action:** Reviewer triages Issues; closing an Issue plus a commit publishes the blocklist entry.
4. **Appeals:** Another Issue labelled `appeal`; status tracked manually.
5. **Hosting / domain:** `*.github.io` HTTPS free; **no custom domain needed**. The existing Pages site could host both CSAE standards and blocklist.
6. **Cost:** **$0** for public repo/basic use; private repos have limits, and Actions minutes are capped on Free.
7. **Security / privacy:** **Poor fit.** Issues are not designed for personal data; a misconfigured public repo would expose reports; report contents (PIDs, room codes, potentially personal info in snippets) would sit in a code host's issue tracker; anonymous abuse/spam is hard to throttle; GitHub API is rate-limited (~5k authenticated requests/hour). **Verdict:** acceptable for the public CSAE standards page only, **not for the report store**. Do not route UGC reports here.

---

### Option 7 — Automated classification API add-on (not a backend on its own)

These **score content**; they do not provide intake, a blocklist, reviewer workflow, or appeals. They can only *assist* triage — human review remains necessary, and Play expects "appropriate action," not "we ran a classifier."

| Service | Free tier | Paid | Notes for Domino Shak |
| --- | --- | --- | --- |
| OpenAI Moderation endpoint | Free | Free | Text + images, 13 categories. Good baseline. |
| Google Perspective API | Active until **2026-12-31**; no new signups since Feb 2026 | — | **Do not build on it** — sunsetting. |
| Deploy (formerly Hive) | No true free tier; "$50+ credits" requires a card; dev limit 100 req/day | Text $0.50/1k, visual $3/1k, audio $0.03/min; higher limits/CSAM detection are quote-only | 14-day default data retention; text cap 1024 chars. |
| Sightengine | 2,000 operations/month (500/day) | ~$2–2.90/1k operations | Text, image, video, audio. |
| Azure AI Content Safety | 5k text + 5k image records/month | $0.375/1k text, $0.75/1k images | Enterprise-oriented. |
| Detoxify / Llama Guard (open weights) | Free model, pay compute | — | Self-host; no Arabic guarantee. |

**Critical caveat:** the app is Arabic-first. Most toxicity classifiers are English-centric; Detoxify covers 7 languages (not Arabic). **Any classifier must be evaluated on Arabic text and Egyptian dialect before being trusted.** Voice-abuse detection is expensive/quote-only and would require uploading audio (explicit consent + privacy-policy update). Recommended stance: use automated scoring only as an optional triage hint; keep human review of short text snippets as the decision basis.

---

## Part D — Cost and hosting summary

| Option | Likely monthly cost at this app's scale | Custom domain needed? | Free tier suitable for production? |
| --- | --- | --- | --- |
| 0. Local only | $0 | No | N/A — non-compliant |
| 1. Cloudflare Workers + D1/KV | **$0** (paid floor $5) | No (`*.workers.dev`) | Yes — most generous quotas |
| 2. Supabase | Free $0 / **~$25** Pro | No | No — pauses after 1 week, no backups |
| 3. Firebase | Blaze likely **$0–$10**, uncapped risk | No | No — Functions need Blaze; no hard cap |
| 4. Appwrite Cloud | Free $0 / **~$25** Pro | No | No — same pausing issue |
| 5. PocketBase on VPS | **~$7–12** | **Yes** (or free DDNS) | Yes — you own the ops |
| 6. GitHub Issues + Pages | $0 | No | No — privacy/ToS fit is poor |
| 7. Classifier add-on | $0 (OpenAI) to $29+/mo | No | Add-on only, not a solution |

Domain registration is **~$10–20/year**; TLS certificates are free (Let's Encrypt / vendor-managed). The developer contact mailbox is the existing `dominoshak.support@gmail.com` (no new cost).

---

## Part E — Cross-cutting security and privacy requirements (any option)

1. **Transport:** HTTPS only; explicit CORS for `http://localhost:8080`; no secrets in the WebView/client.
2. **Signing:** Ed25519 keypair; public key pinned in the app; private key offline or in a server-side secret store **not readable by the public intake path**. Rotate with a versioned key ID.
3. **Intake abuse controls:** schema + size caps, per-IP and per-PID rate limits, Turnstile or equivalent, duplicate suppression by `report_id`/room/PID/reason.
4. **Least privilege:** reviewer interface behind its own auth + MFA; no public endpoint listing reports; RLS/rules scoped to the published blocklist only.
5. **Data minimisation:** no chat archive, no voice audio by default, no email/phone, no location, no contacts. Room code is context, not identity.
6. **IP addresses:** unavoidable; disclose in privacy policy and Data Safety, keep short retention, avoid permanent raw-IP logs where possible.
7. **Retention (starting points, not legal rules):** reports 30–90 days (longer only for an active appeal/legal hold); blocklist entries expire automatically (hours–days for routine cases); audit notes minimal and time-limited.
8. **CSAE/CSAM handling:** priority report category; immediate reviewer alert; removal on actual knowledge; documented NCMEC/regional reporting procedure; named point of contact; preserve minimal evidence only as required.
9. **Client behaviour:** accept only signed lists; keep last valid list on fetch failure; fail closed for newly reported peers; expire entries; never construct a permanent identity graph.
10. **Disclosures before shipping:** privacy policy, Data Safety, UGC declaration, content rating, and the new CSAE standards page must all be updated in the same release that adds the backend. Current AAB must **not** be reused for this.
11. **Honest limitation:** without accounts, a determined offender can return with new IDs; durable bans are unreliable. Say so in the published policy.

---

## Part F — Proposed architecture if approved (not implemented)

```text
Player app (WebView, http://localhost:8080)
   ├─ HTTPS POST /report      → intake Worker: validate, rate-limit, store privately
   └─ HTTPS GET  /blocklist/v1.json → signed JSON, verified with pinned public key
Developer reviewer (private admin route / dashboard)
   └─ triage → action → publish → regenerate signed blocklist
Appeals: in-app token → /appeal → same review queue → reversal in next version
CSAE/CSAM reports: priority queue → remove → report to NCMEC/regional authority
Published web resources (existing GitHub Pages site):
   ├─ privacy policy (already live)
   └─ NEW: CSAE standards page naming Domino Shak / developer, linked in Console
```

Recommended candidate for approval: **Option 1 (Cloudflare)** — no custom domain, $0 at expected volume, strong abuse controls, and a simple signed-file distribution model. Fallback if more control is wanted: **Option 5 (PocketBase + small VPS)** at ~$7–12/month with the ops burden accepted.

---

## Part G — Decisions required before any work begins

| Decision | Owner | Status |
| --- | --- | --- |
| Treat CSS as in-scope and publish CSAE standards + name a contact | Developer | **Open** |
| Choose backend option | Developer | **Open** |
| Approve account creation, possible domain, and any paid tier | Developer | **Open — not authorized** |
| Approve privacy policy / Data Safety / content-rating updates | Developer | Open |
| Define retention windows, appeal window, and reviewer identity | Developer | Open |
| Approve AAB modification, rebuild, and two-device test | Developer | Open |
| Approve Play Console upload/publish | Developer | **Open — not authorized** |

**STOP: no accounts, purchases, domains, deployments, AAB changes, or Play Console actions were performed in preparing this document.**

---

## Part H — Sources

- UGC policy: <https://support.google.com/googleplay/android-developer/answer/9876937?hl=en>
- UGC moderation explainer: <https://support.google.com/googleplay/android-developer/answer/12923286?hl=en>
- Child Safety Standards FAQ: <https://support.google.com/googleplay/android-developer/answer/14747720?hl=en>
- Child Safety Standards full policy: <https://support.google.com/googleplay/android-developer/answer/14585136?hl=en>
- Child Endangerment: <https://support.google.com/googleplay/android-developer/answer/9878809?hl=en>
- Policy Deadlines: <https://support.google.com/googleplay/android-developer/table/12921780?hl=en>
- Age-Restricted Content and Functionality: <https://support.google.com/googleplay/android-developer/answer/16302250?hl=en>
- Families: <https://play.google.com/about/families/children-and-families/>
- Cloudflare pricing: <https://developers.cloudflare.com/workers/platform/pricing>, <https://developers.cloudflare.com/d1/platform/pricing>, <https://developers.cloudflare.com/r2/pricing>
- Supabase pricing: <https://supabase.com/pricing>
- Firebase pricing: <https://firebase.google.com/pricing>, <https://firebase.google.com/docs/projects/billing/firebase-pricing-plans>
- Appwrite pricing: <https://appwrite.io/pricing>
- PocketBase: <https://pocketbase.io> (free, MIT, self-hosted)
- Deploy/Hive pricing: <https://thehive.ai/pricing>
- Perspective shutdown notice: <https://perspectiveapi.com>
- VPS pricing (examples): Hetzner, Vultr, DigitalOcean public price pages, checked 2026-11-18
