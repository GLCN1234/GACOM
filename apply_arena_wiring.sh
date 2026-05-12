#!/bin/bash
set -e
echo "🔌 Wiring GACOM Arena into existing code..."

# ─── 1. pubspec.yaml ── add flutter_webrtc ────────────────────────────────────
PUBSPEC="pubspec.yaml"
if ! grep -q "flutter_webrtc" "$PUBSPEC"; then
  # Insert after connectivity_plus line
  sed -i 's/  connectivity_plus: \^6\.0\.3/  connectivity_plus: ^6.0.3\n  flutter_webrtc: ^0.10.7/' "$PUBSPEC"
  echo "  ✅ pubspec.yaml — added flutter_webrtc"
else
  echo "  ⚠️  pubspec.yaml — flutter_webrtc already present, skipped"
fi

# ─── 2. app_constants.dart ── add arenaRoute ──────────────────────────────────
CONSTANTS="lib/core/constants/app_constants.dart"
if ! grep -q "arenaRoute" "$CONSTANTS"; then
  # Insert after agentChatRoute line
  sed -i "s|  static const agentChatRoute = '/agent-chat';|  static const agentChatRoute = '/agent-chat';\n  static const arenaRoute = '/arena';\n  static const arenaMatchRoute = '/arena/match';|" "$CONSTANTS"
  echo "  ✅ app_constants.dart — added arenaRoute + arenaMatchRoute"
else
  echo "  ⚠️  app_constants.dart — arenaRoute already present, skipped"
fi

# ─── 3. router_service.dart ── imports + routes ───────────────────────────────
ROUTER="lib/core/services/router_service.dart"

if ! grep -q "arena_screen.dart" "$ROUTER"; then
  # Add imports after the exco import line
  sed -i "s|import '../../features/exco/screens/exco_dashboard_screen.dart';|import '../../features/exco/screens/exco_dashboard_screen.dart';\nimport '../../features/arena/screens/arena_screen.dart';\nimport '../../features/arena/screens/match_screen.dart';|" "$ROUTER"
  echo "  ✅ router_service.dart — imports added"
else
  echo "  ⚠️  router_service.dart — arena imports already present, skipped"
fi

if ! grep -q "path: '/arena'" "$ROUTER"; then
  # Insert arena route after the exco-dashboard route
  sed -i "s|GoRoute(path: '/exco-dashboard', builder: (_, __) => const ExcoDashboardScreen()),|GoRoute(path: '/exco-dashboard', builder: (_, __) => const ExcoDashboardScreen()),\n          GoRoute(\n            path: AppConstants.arenaRoute,\n            builder: (_, __) => const ArenaScreen(),\n            routes: [\n              GoRoute(\n                path: 'match/:id',\n                builder: (_, s) => MatchScreen(matchId: s.pathParameters['id']!),\n              ),\n            ],\n          ),|" "$ROUTER"
  echo "  ✅ router_service.dart — arena route added"
else
  echo "  ⚠️  router_service.dart — arena route already present, skipped"
fi

# ─── 4. main_shell.dart ── add Arena tab ──────────────────────────────────────
SHELL="lib/features/home/screens/main_shell.dart"

if ! grep -q "Arena.*route.*arena" "$SHELL"; then
  # Insert Arena tab before the Profile tab (isProfile: true line)
  sed -i "s|    _Tab(icon: Icons.person_rounded,  label: 'Profile',   route: '', isProfile: true),|    _Tab(icon: Icons.sports_esports_rounded, label: 'Arena', route: AppConstants.arenaRoute),\n    _Tab(icon: Icons.person_rounded,  label: 'Profile',   route: '', isProfile: true),|" "$SHELL"
  echo "  ✅ main_shell.dart — Arena tab added"
else
  echo "  ⚠️  main_shell.dart — Arena tab already present, skipped"
fi

# ─── 5. admin_dashboard_screen.dart ── section + import ──────────────────────
ADMIN="lib/features/admin/screens/admin_dashboard_screen.dart"

if ! grep -q "arena_admin_section" "$ADMIN"; then
  # Add import at top (after the last import line pattern)
  sed -i "s|import '../../../shared/widgets/gacom_text_field.dart';|import '../../../shared/widgets/gacom_text_field.dart';\nimport '../../arena/screens/arena_admin_section.dart';|" "$ADMIN"
  echo "  ✅ admin_dashboard_screen.dart — ArenaAdminSection import added"
else
  echo "  ⚠️  admin_dashboard_screen.dart — import already present, skipped"
fi

if ! grep -q "'Arena'" "$ADMIN"; then
  # Add 'Arena' to _sections list (after 'Exco & Roles')
  sed -i "s|final _sections = \['Dashboard', 'Users', 'Competitions', 'Communities', 'Blog', 'Payments', 'Verification', 'Exco \& Roles'\];|final _sections = ['Dashboard', 'Users', 'Competitions', 'Communities', 'Blog', 'Payments', 'Verification', 'Exco \& Roles', 'Arena'];|" "$ADMIN"
  echo "  ✅ admin_dashboard_screen.dart — 'Arena' added to _sections"
else
  echo "  ⚠️  admin_dashboard_screen.dart — 'Arena' already in _sections, skipped"
fi

if ! grep -q "Icons.stadium_rounded\|arena.*icon\|Arena.*icon" "$ADMIN"; then
  # Add arena icon to _sectionIcons
  sed -i "s|final _sectionIcons = \[Icons.dashboard_rounded, Icons.people_rounded, Icons.sports_esports_rounded, Icons.groups_rounded, Icons.article_rounded, Icons.account_balance_wallet_rounded, Icons.verified_rounded, Icons.admin_panel_settings_rounded\];|final _sectionIcons = [Icons.dashboard_rounded, Icons.people_rounded, Icons.sports_esports_rounded, Icons.groups_rounded, Icons.article_rounded, Icons.account_balance_wallet_rounded, Icons.verified_rounded, Icons.admin_panel_settings_rounded, Icons.stadium_rounded];|" "$ADMIN"
  echo "  ✅ admin_dashboard_screen.dart — arena icon added"
fi

if ! grep -q "case 8:" "$ADMIN"; then
  # Add case 8 to _buildSection switch
  sed -i "s|      case 7: return const _ExcoSection();|      case 7: return const _ExcoSection();\n      case 8: return const ArenaAdminSection();|" "$ADMIN"
  echo "  ✅ admin_dashboard_screen.dart — case 8 ArenaAdminSection added"
else
  echo "  ⚠️  admin_dashboard_screen.dart — case 8 already present, skipped"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Arena wiring complete!"
echo ""
echo "Run these next:"
echo ""
echo "  flutter pub get"
echo ""
echo "  # Run SQL in Supabase SQL editor:"
echo "  # supabase/migrations/007_arena_schema.sql"
echo ""
echo "  # Deploy edge function:"
echo "  npx supabase functions deploy arena-payout --no-verify-jwt"
echo ""
echo "  # Add your Metered TURN credentials:"
echo "  # lib/features/arena/services/arena_service.dart"
echo "  # Find turnServers and fill in username + credential"
echo ""
echo "  git add -A && git commit -m 'feat: wire Arena into shell, router, admin' && git push"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
