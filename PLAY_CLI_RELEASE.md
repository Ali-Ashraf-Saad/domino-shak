# Play releases from the CLI (Fastlane Supply)

Fastlane Supply uploads AAB/APK files and selects a Play track without opening
the Play Console. This project runs Supply inside Docker because Ruby is not
installed on the host. No Google credential is stored in the repository.

## One-time setup (owner action)

1. In [Play Console → Account details](https://play.google.com/console/u/0/developers/6581168313428577008/account-details?hl=en),
   note the **Google Cloud project** linked to the developer account.
2. In Google Cloud, enable the
   [Google Play Developer API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?hl=en)
   on that project.
3. Create a **service account** in Google Cloud
   ([Service accounts](https://console.cloud.google.com/iam-admin/serviceaccounts?hl=en)),
   then **Manage keys → Add key → JSON → Create** and download the JSON key.
4. Save the key **outside this repository**, e.g.
   `/home/ali/.config/domino_shak/play-service-account.json`, with mode `0600`.
5. In Play Console → **Users and permissions**, invite the service account
   email with release-management access to `com.dominoshak.domino_shak`.
6. Tell the agent only the **path** to the JSON key. Never paste its contents
   into chat, a file in this repo, or a command argument.

## Usage

```bash
# Build the image once (the wrapper also builds it automatically if missing)
docker build -t domino-supply:latest tools/fastlane

# Check the key / API access
GOOGLE_JSON_KEY=/home/ali/.config/domino_shak/play-service-account.json \
  ./tools/play_supply.sh validate_auth

# Upload the current signed AAB to a track (internal | alpha | production)
GOOGLE_JSON_KEY=/home/ali/.config/domino_shak/play-service-account.json \
  ./tools/play_supply.sh upload_alpha

# Promote the active internal-testing release to closed testing (alpha)
GOOGLE_JSON_KEY=/home/ali/.config/domino_shak/play-service-account.json \
  ./tools/play_supply.sh promote_alpha
```

The wrapper mounts the key read-only at `/keys/play.json` and passes only that
container path to Fastlane. Store listings, icons, and screenshots are never
uploaded (`skip_upload_metadata/images/screenshots`). Release notes come from
`fastlane/metadata/android/ar-SA/changelogs/<versionCode>.txt`.

## Tracks

| CLI track | Play Console label |
| --- | --- |
| `internal` | الاختبار الداخلي / Internal testing |
| `alpha` | الاختبار المغلق - Alpha / Closed testing |
| `production` | الإنتاج / Production |

`promote_alpha` uses Supply's `track_promote_to`; Google Play deactivates the
release on the source track when it is promoted. `upload_alpha` instead uploads
the AAB as a new release on alpha and keeps the internal release active.
