#!/bin/bash
# Uploads release_out/ (built by release_android.sh) to the app-releases bucket.
# Usage:  export SUPABASE_SERVICE_KEY='sb_secret_...'   (or the old service_role key)
#         bash upload_release.sh
if [ -z "$SUPABASE_SERVICE_KEY" ]; then echo "Set SUPABASE_SERVICE_KEY first."; exit 1; fi
OUT=release_out
API="${SUPABASE_URL:-https://rxccipqvyrcfpsadgpzp.supabase.co}/storage/v1/object/app-releases"
# New secret keys (sb_secret_...) are not JWTs: send them only as apikey.
# Old service_role keys are JWTs: send them both ways.
if [[ "$SUPABASE_SERVICE_KEY" == sb_* ]]; then
  AUTH=(-H "apikey: $SUPABASE_SERVICE_KEY")
else
  AUTH=(-H "apikey: $SUPABASE_SERVICE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_KEY")
fi
up() {
  local code
  code=$(curl -sS -o /tmp/up_resp.txt -w '%{http_code}' -X POST "$API/$1" "${AUTH[@]}" \
    -H "x-upsert: true" -H "cache-control: max-age=60" \
    -H "Content-Type: $2" --data-binary "@$OUT/$1")
  if [ "$code" = "200" ] || [ "$code" = "201" ]; then
    echo "uploaded $1"
  else
    echo "FAILED $1 (HTTP $code): $(cat /tmp/up_resp.txt)"
    exit 1
  fi
}
if [ -f "$OUT/gacom-latest.apk" ]; then up gacom-latest.apk application/vnd.android.package-archive; fi
if [ -f "$OUT/gacom-latest-arm64.apk" ]; then up gacom-latest-arm64.apk application/vnd.android.package-archive; fi
up latest.json application/json
echo "Done. People are offered this build the next time they open the app."
