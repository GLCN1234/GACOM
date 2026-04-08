#!/bin/bash
# ============================================================
# GACOM FIX PATCH - apply_patch.sh
# Run this in your GitHub Codespace terminal:
#   bash apply_patch.sh
# ============================================================

set -e

PATCH_ZIP="gacom_fix_patch.zip"
PROJECT_ROOT="."   # adjust if your project is in a subfolder

echo "🔧 Applying GACOM fix patch..."

# 1. Unzip patch
if [ ! -f "$PATCH_ZIP" ]; then
  echo "❌ $PATCH_ZIP not found. Make sure the zip is in the same folder as this script."
  exit 1
fi

unzip -o "$PATCH_ZIP" -d /tmp/gacom_fix_tmp

# 2. Copy all dart files into project
echo "📁 Copying fixed files..."

cp /tmp/gacom_fix_tmp/lib/features/admin/screens/admin_dashboard_screen.dart \
   "$PROJECT_ROOT/lib/features/admin/screens/admin_dashboard_screen.dart"

cp /tmp/gacom_fix_tmp/lib/features/feed/screens/create_post_screen.dart \
   "$PROJECT_ROOT/lib/features/feed/screens/create_post_screen.dart"

cp /tmp/gacom_fix_tmp/lib/features/store/screens/store_screen.dart \
   "$PROJECT_ROOT/lib/features/store/screens/store_screen.dart"

cp /tmp/gacom_fix_tmp/supabase/migrations/002_fix_rls_storage_exco.sql \
   "$PROJECT_ROOT/supabase/migrations/002_fix_rls_storage_exco.sql"

# 3. Cleanup
rm -rf /tmp/gacom_fix_tmp

echo ""
echo "✅ Patch applied! Files updated:"
echo "   - lib/features/admin/screens/admin_dashboard_screen.dart"
echo "   - lib/features/feed/screens/create_post_screen.dart"
echo "   - lib/features/store/screens/store_screen.dart"
echo "   - supabase/migrations/002_fix_rls_storage_exco.sql"
echo ""
echo "🗄️  IMPORTANT — Run the SQL migration in Supabase:"
echo "   1. Open https://supabase.com/dashboard"
echo "   2. Select your project → SQL Editor"
echo "   3. Paste the contents of supabase/migrations/002_fix_rls_storage_exco.sql"
echo "   4. Click RUN"
echo ""
echo "🚀 Then rebuild: flutter build web --release"
