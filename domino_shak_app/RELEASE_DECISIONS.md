# Release decisions — 2026-11-18

Recorded decisions from the project owner. This file is documentation only; it
does not authorize publishing or uploading anything.

| Decision | Outcome | Notes |
| --- | --- | --- |
| Final `applicationId` | **`com.dominoshak.domino_shak`** | Confirmed as final. Do not change after the first Play release. |
| Signing | **Play App Signing** | A local *upload* keystore may be generated with a random password stored only in an untracked secret file. Google holds the app-signing key after enrollment. No password is printed, logged, or committed. |
| UGC moderation | **Approve the design only** | No-account report intake + signed blocklist design is approved for documentation. No accounts, domains, deployment, or paid services are authorized without a separate explicit approval. Local report/block controls are shipped but are not moderation. |
| Store assets | **Draft now** | `play_store_assets/` drafted from real device screenshots and the shipped launcher icon. Nothing is uploaded. |
| Developer contact + public privacy URL | **Provided and confirmed live** | `Domino Shak` / `دومينو شك`, `dominoshak.support@gmail.com`, repo `https://github.com/Ali-Ashraf-Saad/dominoshak-privacy`, URL `https://ali-ashraf-saad.github.io/dominoshak-privacy/`. Owner confirmed public HTTPS access on 2026-11-18; final AAB rebuilt and verified. Play upload still not authorized. |
| Play Console upload | **Not authorized** | Requires a separate explicit approval. No upload, rollout, or publish has been performed. |

## Scope reminders

- Android only; iOS is out of scope.
- Original website `../index.html` stays byte-for-byte unchanged.
- Fixed trusted origin `http://localhost:8080`; never `file://`.
- No Wi-Fi/mobile-data changes and no mobile-data use without approval.
- No TURN server is configured.
