#!/bin/bash
# ============================================================
# GACOM Patch 8 — Build Fix (chat_detail_screen.dart)
# Run from your GACOM repo root: bash patch8/install.sh
# ============================================================
set -e

PATCH_DIR="$(dirname "$0")"
REPO_ROOT="$(pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GACOM Patch 8 — Netlify Build Fix"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$REPO_ROOT/pubspec.yaml" ]; then
  echo "❌ Run this from your GACOM repo root"
  exit 1
fi

mkdir -p "$REPO_ROOT/lib/features/chat/screens"

cp "$PATCH_DIR/lib/features/chat/screens/chat_detail_screen.dart" \
   "$REPO_ROOT/lib/features/chat/screens/chat_detail_screen.dart"

echo "✅ chat_detail_screen.dart patched"
echo ""
echo "Now commit and push:"
echo "  git add -A && git commit -m 'fix: dart web ternary ?[] compile error' && git push"
echo ""
