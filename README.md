# GACOM - Gaming Social Platform

> Game. Connect. Dominate.

A full-stack gaming social platform built with Flutter + Supabase.

---

## 🚀 Quick Setup

### 1. Install Flutter
```bash
flutter channel stable
flutter upgrade
```

### 2. Set up Supabase
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Go to **SQL Editor** → New Query
3. Paste the entire contents of `supabase/migrations/001_initial_schema.sql` and run it
4. Go to **Storage** → Create these buckets (all public):
   - `avatars`
   - `post-media`
   - `product-images`
   - `blog-images`
   - `community-banners`

### 3. Configure Your Keys

Edit `lib/core/constants/app_constants.dart`:
```dart
static const supabaseUrl = 'https://YOURPROJECTID.supabase.co';
static const supabaseAnonKey = 'YOUR_ANON_KEY'; // From Project Settings > API
static const paystackPublicKey = 'pk_live_XXXXXXXXXX'; // Your Paystack key
```

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Run the App
```bash
# Web
flutter run -d chrome

# Mobile
flutter run
```

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/       # App constants, routes
│   ├── theme/           # Dark theme, colors
│   └── services/        # Router, Supabase
├── features/
│   ├── auth/            # Login, Register, Onboarding, Splash
│   ├── home/            # Main shell, Search, Notifications
│   ├── feed/            # Posts feed, Create post
│   ├── competitions/    # Competition list & detail, joining
│   ├── community/       # Communities, sub-communities
│   ├── chat/            # Real-time messaging
│   ├── store/           # E-commerce, cart
│   ├── wallet/          # Wallet, Paystack payments
│   ├── blog/            # Blog list & detail
│   ├── profile/         # Profile, settings
│   └── admin/           # Full admin dashboard
└── shared/
    └── widgets/         # Reusable UI components
```

---

## 🗄️ Supabase Schema

The schema includes 25+ tables:
- **profiles** – Users with wallet, stats, verification
- **posts** – Content with media, likes, comments
- **competitions** – Tournaments with entry fees, prize pools
- **communities** – Gaming groups with sub-communities
- **chats / messages** – Real-time chat
- **products / orders** – E-commerce store
- **wallet_transactions** – Payment history
- **blog_posts** – Admin-only blog
- **verification_requests** – KYC verification
- **notifications** – Push notifications
- **admin_permissions** – Fine-grained admin access control

All tables have Row Level Security (RLS) policies, triggers for counter updates, and real-time subscriptions.

---

## 💳 Paystack Integration

Payments are handled via Paystack WebView:
1. User funds wallet → opens Paystack checkout
2. On success → updates wallet balance in Supabase
3. Competition entry fees deducted from wallet
4. Withdrawals processed via bank account

---

## 🔐 Admin Dashboard

Access via `/admin` route (admin/super_admin role required).

Features:
- Dashboard overview with live stats
- User management (ban/unban, role management)
- Verification request review (approve/reject)
- Admin account creation with permission assignment
- Competitions, Blog, Store, Payments sections

---

## 🎨 Design System

**Brand Colors:**
- Primary: `#E84B00` (Deep Orange)
- Background: `#090909` (Obsidian)
- Cards: `#1A1A1A`
- Text: `#F5F5F5`

**Font:** Rajdhani (bold, gaming aesthetic)

---

## 🔗 Deployment

### Flutter Web → Netlify
```bash
flutter build web --release
# Upload build/web/ to Netlify
```

Or connect your GitHub repo to Netlify with build command:
```
flutter build web --release
```
Publish directory: `build/web`

---

## 📱 Mobile (Coming Soon)
The same codebase runs on iOS/Android. When ready:
```bash
flutter build apk   # Android
flutter build ios   # iOS
```

---

## ⚙️ Environment Config

For production, replace hardcoded keys with environment variables using `--dart-define`:
```bash
flutter build web --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_KEY=...
```

Then in constants:
```dart
static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
```
