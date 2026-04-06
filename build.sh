#!/bin/bash
set -e

# Clone Flutter
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add to PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify we're in repo root
echo "Current dir: $(pwd)"
echo "pubspec.yaml exists: $(ls pubspec.yaml)"

# Setup Flutter
flutter config --enable-web
flutter pub get

# Build
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=PAYSTACK_PUBLIC_KEY=$PAYSTACK_PUBLIC_KEY
