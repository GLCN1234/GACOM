#!/bin/bash
# Uploads release_out/ (built by release_android.sh) to the app-releases bucket.
# Usage:  export SUPABASE_SERVICE_KEY='sb_secret_...'   (or the old service_role key)
#         bash upload_release.sh
set -e
if [ -z "$SUPABASE_SERVICE_KEY" ]; then echo "Set SUPABASE_SERVICE_KEY first."; exit 1; fi
OUT=release_out
API="${SUPABASE_URL:-https://rxccipqvyrcfpsadgpzp.supabase.co}/storage/v1/object/app-releases"
up() {
  curl -sS -f -X POST "$API/$1" \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "x-upsert: true" -H "cache-control: max-age=60" \
    -H "Content-Type: $2" --data-binary "@$OUT/$1" > /dev/null
  echo "uploaded $1"
}
up gacom-latest.apk application/vnd.android.package-archive
if [ -f "$OUT/gacom-latest-arm64.apk" ]; then up gacom-latest-arm64.apk application/vnd.android.package-archive; fi
up latest.json application/json
echo "Done. People are offered this build the next time they open the app."
