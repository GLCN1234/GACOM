#!/bin/bash
# ============================================================
# GACOM Patch Part 2 — Copy new files into place
# Run from your project root:  bash apply_patch_v2.sh
# ============================================================
PATCH_DIR="gacom_fix_v2"

echo "📦 Copying patched files..."

copy_file() {
  local src="$1" dst="$2"
  if [ -f "$src" ]; then
    cp "$src" "$dst" && echo "  ✅ $dst"
  else
    echo "  ⚠️  SKIP (not found): $src"
  fi
}

copy_file "$PATCH_DIR/lib/core/theme/app_theme.dart"                          lib/core/theme/app_theme.dart
copy_file "$PATCH_DIR/lib/core/services/router_service.dart"                  lib/core/services/router_service.dart
copy_file "$PATCH_DIR/lib/features/home/screens/main_shell.dart"              lib/features/home/screens/main_shell.dart
copy_file "$PATCH_DIR/lib/main.dart"                                           lib/main.dart
copy_file "$PATCH_DIR/lib/features/store/screens/cart_screen.dart"            lib/features/store/screens/cart_screen.dart
copy_file "$PATCH_DIR/lib/features/store/screens/product_detail_screen.dart"  lib/features/store/screens/product_detail_screen.dart
copy_file "$PATCH_DIR/lib/features/store/screens/store_screen.dart"           lib/features/store/screens/store_screen.dart

echo "✅ Files copied."
echo ""
echo "🎨 Running theme colour patch across all screens..."
bash "$PATCH_DIR/apply_theme_fix.sh"

echo ""
echo "🔧 Fixing settings screen scaffold background..."
# Settings screen still has a hardcoded obsidian bg — patch it specifically
sed -i 's/backgroundColor: GacomColors\.obsidian/backgroundColor: GacomColors.bg(context)/g' \
    lib/features/profile/screens/settings_screen.dart

echo ""
echo "📋 Running flutter analyze to check for issues..."
flutter analyze lib --no-fatal-warnings 2>&1 | tail -30 || true

echo ""
echo "🚀 All done! Run:  flutter run -d chrome  to test."
