# 🚀 GACOM UI MEGA PATCH

## What's inside

This patch completely overhauls the Gacom Flutter app UI with a **futuristic cyberpunk-luxury aesthetic** — dark blacks, glowing orange accents, glassmorphism, animated backgrounds, and premium interactions.

---

## Files in this patch

```
lib/
├── core/theme/app_theme.dart            ← Upgraded color system, GacomDecorations helper
├── features/
│   ├── home/screens/main_shell.dart     ← Glassmorphism nav bar, animated FAB
│   ├── feed/screens/feed_screen.dart    ← Animated post cards, skeleton shimmer
│   ├── auth/screens/login_screen.dart   ← Animated bg grid, glassmorphism login
│   ├── profile/screens/
│   │   ├── profile_screen.dart          ← Glow avatar, wins tab, edit profile sheet
│   │   └── settings_screen.dart         ← Verification flow (3-step), Ads/Promotion CTA
│   └── ads/screens/ads_screen.dart      ← Full ads creation + campaigns management
```

---

## Apply in 3 commands (GitHub Codespace)

```bash
# 1. Unzip in your project root (where pubspec.yaml is)
cd /workspaces/GACOM
unzip gacom_ui_patch.zip -d .

# 2. Confirm files were placed correctly
ls lib/core/theme/app_theme.dart
ls lib/features/ads/screens/ads_screen.dart

# 3. Run the app
flutter run -d chrome
```

---

## Router — add the Ads route

Open `lib/core/services/router_service.dart` and add inside the `ShellRoute` routes list:

```dart
GoRoute(
  path: '/ads',
  builder: (context, state) => const AdsScreen(),
),
```

Also add this import at the top:

```dart
import '../../features/ads/screens/ads_screen.dart';
```

---

## New Features added

### ✅ Profile Screen
- Glow avatar with orange ring for verified users
- 3 tabs: Posts, Clips, **Wins** (competition results)
- Edit Profile bottom sheet (name, bio, gamer tag, location, website)
- Verification CTA banner for unverified users
- Follow/Unfollow with animation

### ✅ Settings Screen
- Profile header card with wallet balance
- **Verification flow** — 3-step modal: Overview → Identity → Documents
- **Run an Ad** — full campaign creation sheet
- All settings sections: Account, Promotions, Preferences, Support, Danger Zone

### ✅ Ads / Promotions Screen (`/ads`)
- Choose what to promote: Profile, Post, or Clip
- Campaign objective: Awareness, Followers, or Engagement
- Budget picker: ₦500–₦10,000/day
- Duration picker with animated counter
- Real-time campaign summary with estimated reach
- My Campaigns tab with live/ended status

### ✅ Feed Screen
- Staggered animate-in for post cards
- Skeleton shimmer loading state
- Glassmorphism post cards
- Glowing notification badge
- GACOM BETA logo badge

### ✅ Login Screen
- Animated background grid with glowing orb
- Glassmorphism text fields
- Social login buttons (Google/Discord)
- Smooth slide/fade animations

### ✅ Nav Shell
- Glassmorphism bottom nav bar (BackdropFilter)
- Animated FAB with shimmer effect
- Active indicator with orange glow highlight

---

## Design System

```dart
// Colors
GacomColors.deepOrange   // #E84B00 — primary brand
GacomColors.obsidian     // #080808 — background
GacomColors.cardDark     // #161616 — cards
GacomColors.glowOrange   // #FF7A3D — glow effects

// Decorations
GacomDecorations.glassCard(radius: 20)        // Standard glass card
GacomDecorations.orangeGlow(radius: 20)        // Orange gradient with glow shadow
GacomDecorations.orangeBorder(radius: 20)      // Card with orange border glow
```

---

## pubspec.yaml — confirm these are present

All packages used are already in your pubspec.yaml:
- `flutter_animate` — entry animations, shimmer
- `google_fonts` — Rajdhani font
- `cached_network_image` — avatar/post images
- `go_router` — navigation
- `supabase_flutter` — backend
