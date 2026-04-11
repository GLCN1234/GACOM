#!/bin/bash
# ============================================================
# GACOM Patch 6 — Install Script
# Run from your GACOM repo root: bash patch6/install.sh
# ============================================================

set -e

PATCH_DIR="$(dirname "$0")"
REPO_ROOT="$(pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GACOM Patch 6 — Installing..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify we're in the right place
if [ ! -f "$REPO_ROOT/pubspec.yaml" ]; then
  echo "❌ ERROR: Run this from your GACOM repo root (where pubspec.yaml is)"
  exit 1
fi

echo "✅ Repo root confirmed: $REPO_ROOT"
echo ""

# Copy SQL
echo "📋 Copying SQL patch..."
cp "$PATCH_DIR/supabase/patch6.sql" "$REPO_ROOT/supabase/migrations/004_patch6.sql"
echo "   → supabase/migrations/004_patch6.sql"

# Copy Dart files
echo ""
echo "📋 Copying Dart files..."

mkdir -p "$REPO_ROOT/lib/features/community/screens"
mkdir -p "$REPO_ROOT/lib/features/competitions/screens"

cp "$PATCH_DIR/lib/features/community/screens/gaming_teams_screen.dart" \
   "$REPO_ROOT/lib/features/community/screens/gaming_teams_screen.dart"
echo "   → lib/features/community/screens/gaming_teams_screen.dart"

cp "$PATCH_DIR/lib/features/competitions/screens/tournament_manager_screen.dart" \
   "$REPO_ROOT/lib/features/competitions/screens/tournament_manager_screen.dart"
echo "   → lib/features/competitions/screens/tournament_manager_screen.dart"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Patch 6 installed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Run the SQL in Supabase:"
echo "   → Supabase Dashboard > SQL Editor"
echo "   → Open: supabase/migrations/004_patch6.sql"
echo "   → Click Run"
echo ""
echo "2. Add these imports to your router or wherever you navigate:"
echo "   import 'package:gacom/features/community/screens/gaming_teams_screen.dart';"
echo "   import 'package:gacom/features/competitions/screens/tournament_manager_screen.dart';"
echo ""
echo "3. To open Gaming Teams (add to community_detail_screen.dart):"
echo "   context.push('/communities/COMMUNITYID/teams')"
echo "   or: Navigator.push(context, MaterialPageRoute(builder: (_) => GamingTeamsScreen(communityId: id)))"
echo ""
echo "4. To open Tournament Manager from competition detail:"
echo "   Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentManagerScreen(competitionId: id, isAdmin: isAdmin)))"
echo ""
echo "5. Commit and push:"
echo "   git add -A && git commit -m 'feat: patch6 - tournament system, gaming teams, chat fix' && git push"
echo ""
