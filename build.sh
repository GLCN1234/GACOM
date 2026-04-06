#!/bin/bash
set -e

REPO_ROOT=$(pwd)
echo "Repo root: $REPO_ROOT"
echo "Files here: $(ls)"

# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add flutter to PATH
export PATH="$PATH:$REPO_ROOT/flutter/bin"

# Go back to repo root just to be safe
cd $REPO_ROOT

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=PAYSTACK_PUBLIC_KEY=$PAYSTACK_PUBLIC_KEY
