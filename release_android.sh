#!/bin/bash
# Builds the two GACOM Android files (standard and small 64-bit), writes the
# release manifest, and uploads everything to the app-releases bucket.
#
# Usage:   bash release_android.sh "First note|Second note"
# Needs:   the version line in pubspec.yaml bumped first (for example 1.0.1+2),
#          android/key.properties pointing at your release keystore, and
#          these env vars (same ones the web build uses):
#            SUPABASE_URL SUPABASE_ANON_KEY PAYSTACK_PUBLIC_KEY LIVEKIT_URL
#          To upload automatically also set SUPABASE_SERVICE_KEY.
set -e

NOTES="${1:-Bug fixes and improvements}"
OUT=release_out
BASE="${SUPABASE_URL:-https://rxccipqvyrcfpsadgpzp.supabase.co}/storage/v1/object/public/app-releases"

VERSION_LINE=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
VERSION="${VERSION_LINE%%+*}"
BUILD="${VERSION_LINE##*+}"
echo "Building GACOM $VERSION (build $BUILD)"

# Keys are already built into the app as defaults (lib/core/constants/app_constants.dart),
# so nothing has to be typed. Only values that are actually set are passed on.
DEFINES="--split-debug-info=build/symbols --dart-define=APP_BUILD=$BUILD"
for K in SUPABASE_URL SUPABASE_ANON_KEY PAYSTACK_PUBLIC_KEY LIVEKIT_URL; do
  if [ -n "${!K}" ]; then DEFINES="$DEFINES --dart-define=$K=${!K}"; fi
done

flutter pub get

# ARM64_ONLY=1 builds one 64-bit ARM file (about a third of the size, fits the 50 MB
# Supabase free-plan limit, runs on almost every phone made in the last several years).
rm -rf "$OUT" && mkdir -p "$OUT"
if [ -n "$ARM64_ONLY" ]; then
  flutter build apk --release --target-platform android-arm64 $DEFINES
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT/gacom-latest-arm64.apk"
else
  # standard build: works on every Android phone
  flutter build apk --release $DEFINES
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT/gacom-latest.apk"
  # small build: 64-bit ARM only. Needs a lot of memory; set SKIP_ARM64=1 to leave it out.
  if [ -z "$SKIP_ARM64" ]; then
    (cd android && ./gradlew --stop >/dev/null 2>&1) || true
    if flutter build apk --release --split-per-abi $DEFINES; then
      cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$OUT/gacom-latest-arm64.apk"
    else
      echo "Small build failed (probably memory). Continuing with the standard build only."
    fi
  fi
fi

python3 - "$VERSION" "$BUILD" "$NOTES" "$BASE" <<'PY'
import hashlib, json, os, sys
version, build, notes, base = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
def info(name):
    p = os.path.join('release_out', name)
    h = hashlib.sha256(open(p, 'rb').read()).hexdigest()
    return round(os.path.getsize(p) / 1048576, 1), h
has_full = os.path.exists(os.path.join('release_out', 'gacom-latest.apk'))
fm, fh = info('gacom-latest.apk') if has_full else (0, '')
has_arm = os.path.exists(os.path.join('release_out', 'gacom-latest-arm64.apk'))
am, ah = info('gacom-latest-arm64.apk') if has_arm else (0, '')
m = {
    'version': version, 'build': build, 'min_build': 1,
    'notes': [n.strip() for n in notes.split('|') if n.strip()],
    'full_url': (base + '/gacom-latest.apk') if has_full else (base + '/gacom-latest-arm64.apk'), 'full_mb': fm if has_full else am, 'full_sha256': fh if has_full else ah,
    'arm64_url': (base + '/gacom-latest-arm64.apk') if has_arm else '', 'arm64_mb': am, 'arm64_sha256': ah,
}
json.dump(m, open('release_out/latest.json', 'w'), indent=2)
big = max(fm, am)
print('\nLargest file: %.1f MB %s' % (big, '(fits the 50 MB Supabase limit)' if big < 49 else '(over 50 MB: upload_release.sh will use the GitHub route)'))
print(json.dumps(m, indent=2))
PY

if [ -n "$SUPABASE_SERVICE_KEY" ]; then
  API="${SUPABASE_URL:-https://rxccipqvyrcfpsadgpzp.supabase.co}/storage/v1/object/app-releases"
  up() {
    curl -sS -f -X POST "$API/$1" \
      -H "apikey: $SUPABASE_SERVICE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
      -H "x-upsert: true" -H "cache-control: max-age=60" \
      -H "Content-Type: $2" --data-binary "@$OUT/$1" > /dev/null
    echo "uploaded $1"
  }
  # files first, manifest last, so nobody is told about a build that is not there yet
  if [ -f "$OUT/gacom-latest.apk" ]; then up gacom-latest.apk application/vnd.android.package-archive; fi
  if [ -f "$OUT/gacom-latest-arm64.apk" ]; then up gacom-latest-arm64.apk application/vnd.android.package-archive; fi
  up latest.json application/json
  echo "Done. People will be offered build $BUILD the next time they open the app."
else
  echo
  echo "Files are in $OUT/. Upload all three to the app-releases bucket (replace existing),"
  echo "APKs first and latest.json last. Or set SUPABASE_SERVICE_KEY and run this again."
fi
