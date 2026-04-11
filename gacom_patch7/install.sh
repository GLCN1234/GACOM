#!/bin/bash
# ============================================================
# GACOM Patch 7 — Install Script
# Run from your GACOM repo root: bash patch7/install.sh
# ============================================================
set -e

PATCH_DIR="$(dirname "$0")"
REPO_ROOT="$(pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GACOM Patch 7 — Chat Fix + UI Redesign"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -f "$REPO_ROOT/pubspec.yaml" ]; then
  echo "❌ ERROR: Run this from your GACOM repo root"
  exit 1
fi
echo "✅ Repo root: $REPO_ROOT"

# ── SQL ──────────────────────────────────────────────────────────────────────
echo ""
echo "📋 Copying SQL..."
mkdir -p "$REPO_ROOT/supabase/migrations"
cp "$PATCH_DIR/supabase/patch7_chat_fix.sql" \
   "$REPO_ROOT/supabase/migrations/005_patch7_chat_fix.sql"
echo "   → supabase/migrations/005_patch7_chat_fix.sql"

# ── Dart files ────────────────────────────────────────────────────────────────
echo ""
echo "📋 Copying Dart files..."

mkdir -p "$REPO_ROOT/lib/features/chat/screens"
mkdir -p "$REPO_ROOT/lib/features/feed/screens"
mkdir -p "$REPO_ROOT/lib/features/blog/screens"
mkdir -p "$REPO_ROOT/lib/features/home/screens"

cp "$PATCH_DIR/lib/features/chat/screens/chat_list_screen.dart" \
   "$REPO_ROOT/lib/features/chat/screens/chat_list_screen.dart"
echo "   → chat_list_screen.dart (redesigned + infinite recursion fixed)"

cp "$PATCH_DIR/lib/features/feed/screens/reels_screen.dart" \
   "$REPO_ROOT/lib/features/feed/screens/reels_screen.dart"
echo "   → reels_screen.dart (redesigned TikTok-style)"

cp "$PATCH_DIR/lib/features/blog/screens/blog_screen.dart" \
   "$REPO_ROOT/lib/features/blog/screens/blog_screen.dart"
echo "   → blog_screen.dart (full public blog with categories + featured carousel)"

cp "$PATCH_DIR/lib/features/home/screens/main_shell.dart" \
   "$REPO_ROOT/lib/features/home/screens/main_shell.dart"
echo "   → main_shell.dart (Blog added to bottom nav, replaces Store slot)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Files installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NEXT — Do these in order:"
echo ""
echo "1. RUN THE SQL (MOST IMPORTANT):"
echo "   → Supabase Dashboard > SQL Editor"
echo "   → Paste entire contents of:"
echo "      supabase/migrations/005_patch7_chat_fix.sql"
echo "   → Click Run"
echo "   This fixes the infinite recursion in chat_members RLS."
echo ""
echo "2. Commit and push:"
echo "   git add -A && git commit -m 'patch7: fix chat infinite recursion, redesign chat/reels/blog' && git push"
echo ""
echo "WHAT CHANGED:"
echo "  ✅ Chat 500 / infinite recursion FIXED (SQL function breaks the cycle)"
echo "  ✅ Chat screen redesigned (story row, online indicators, search by name)"  
echo "  ✅ Reels screen redesigned (full TikTok style, dark overlay, actions)"
echo "  ✅ Blog is now visible in bottom nav (replaced Store - Store still in FAB)"
echo "  ✅ Blog has featured carousel, category tabs, article cards"
echo ""
