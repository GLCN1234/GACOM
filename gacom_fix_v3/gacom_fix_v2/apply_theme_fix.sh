#!/bin/bash
# ============================================================
# GACOM Light Mode Patch — apply_theme_fix.sh
# Run from your project root:  bash apply_theme_fix.sh
# ============================================================

set -e
ROOT="lib"

echo "🎨 Patching hardcoded GacomColors references to context-aware helpers..."

# Files to patch — all dart files except app_theme.dart itself
FILES=$(find "$ROOT" -name "*.dart" \
  ! -path "*/app_theme.dart" \
  ! -path "*/main.dart")

patch_file() {
  local f="$1"

  # ── Scaffold / page backgrounds ──────────────────────────────────────────
  # backgroundColor: GacomColors.obsidian  →  backgroundColor: GacomColors.bg(context)
  sed -i 's/backgroundColor: GacomColors\.obsidian/backgroundColor: GacomColors.bg(context)/g' "$f"
  sed -i 's/backgroundColor: GacomColors\.darkVoid/backgroundColor: GacomColors.bg(context)/g' "$f"
  sed -i 's/color: GacomColors\.obsidian\b/color: GacomColors.bg(context)/g' "$f"
  sed -i 's/color: GacomColors\.darkVoid\b/color: GacomColors.navBg(context)/g' "$f"

  # ── Surface (app bar, sheet bg, panels) ──────────────────────────────────
  sed -i 's/backgroundColor: GacomColors\.surfaceDark/backgroundColor: GacomColors.surface(context)/g' "$f"
  sed -i 's/color: GacomColors\.surfaceDark\b/color: GacomColors.surface(context)/g' "$f"
  sed -i 's/fillColor: GacomColors\.surfaceDark/fillColor: GacomColors.surface(context)/g' "$f"

  # ── Card ──────────────────────────────────────────────────────────────────
  sed -i 's/backgroundColor: GacomColors\.cardDark/backgroundColor: GacomColors.card(context)/g' "$f"
  sed -i 's/color: GacomColors\.cardDark\b/color: GacomColors.card(context)/g' "$f"
  sed -i 's/fillColor: GacomColors\.cardDark/fillColor: GacomColors.card(context)/g' "$f"

  # ── Elevated card ─────────────────────────────────────────────────────────
  sed -i 's/backgroundColor: GacomColors\.elevatedCard/backgroundColor: GacomColors.elevated(context)/g' "$f"
  sed -i 's/color: GacomColors\.elevatedCard\b/color: GacomColors.elevated(context)/g' "$f"

  # ── Border ────────────────────────────────────────────────────────────────
  sed -i 's/color: GacomColors\.border\b/color: GacomColors.borderColor(context)/g' "$f"
  sed -i 's/BorderSide(color: GacomColors\.border\b/BorderSide(color: GacomColors.borderColor(context)/g' "$f"
  sed -i 's/color: GacomColors\.borderBright\b/color: GacomColors.borderStrong(context)/g' "$f"

  # ── Text colours ──────────────────────────────────────────────────────────
  sed -i 's/color: GacomColors\.textPrimary\b/color: GacomColors.txtPrimary(context)/g' "$f"
  sed -i 's/color: GacomColors\.textSecondary\b/color: GacomColors.txtSecondary(context)/g' "$f"
  sed -i 's/color: GacomColors\.textMuted\b/color: GacomColors.txtMuted(context)/g' "$f"

  # ── TextStyle shorthand inside const TextStyle ────────────────────────────
  # These can't be const anymore once they use context — handled by removing const
  # where the parent container already provides context. The replacements above
  # will cause compile errors on const TextStyle — fix those by stripping const:
  sed -i 's/const TextStyle(\(.*\)color: GacomColors\.txt/TextStyle(\1color: GacomColors.txt/g' "$f"
}

for f in $FILES; do
  patch_file "$f"
  echo "  ✅ $f"
done

echo ""
echo "🎨 Done patching $(echo "$FILES" | wc -l) files."
echo ""
echo "⚠️  IMPORTANT: Some 'const' keywords on TextStyle/Container/BoxDecoration"
echo "   may cause compile errors because context-aware calls can't be const."
echo "   Fix by removing 'const' from the affected widget. The patch above"
echo "   handles the most common TextStyle cases automatically."
echo ""
echo "🔧 Run:  flutter analyze lib  to see remaining issues."
