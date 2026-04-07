#!/bin/bash
set -e

REPO_ROOT=$(pwd)
echo "Working from: $REPO_ROOT"

if [ ! -d "$REPO_ROOT/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter already exists, skipping clone."
fi

export PATH="$PATH:$REPO_ROOT/flutter/bin"

flutter config --enable-web
flutter create . --platforms web
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=PAYSTACK_PUBLIC_KEY=$PAYSTACK_PUBLIC_KEY
