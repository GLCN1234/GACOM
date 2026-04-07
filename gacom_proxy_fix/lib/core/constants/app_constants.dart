class AppConstants {
  // App Info
  static const appName = 'GACOM';
  static const appTagline = 'Game. Connect. Dominate.';
  static const appVersion = '1.0.0';

  // Supabase — URL points to Netlify proxy to avoid ERR_QUIC_PROTOCOL_ERROR.
  // The proxy rule in netlify.toml forwards /supabase-proxy/* → Supabase server-side.
  // In local dev (flutter run) use the real URL via --dart-define or just swap back.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rxccipqvyrcfpsadgpzp.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ4Y2NpcHF2eXJjZnBzYWRncHpwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1MDgzMDYsImV4cCI6MjA5MTA4NDMwNn0.XYFX3fyA8F57dTmfApRD0-Ub3cziKFz8o5IyAoGt5dw',
  );

  // The proxy base — used ONLY on web builds deployed to Netlify.
  // supabase_flutter will use supabaseUrl above; this proxy works because
  // Netlify rewrites /supabase-proxy/* to the real Supabase host.
  static const supabaseProxyUrl = '/supabase-proxy';

  // Paystack
  static const paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: 'pk_live_6e268b9f79535f285acad8a437b946a9f6f6f441',
  );
  static const paystackBaseUrl = 'https://api.paystack.co';

  // Storage Buckets
  static const avatarBucket = 'avatars';
  static const postMediaBucket = 'post-media';
  static const productImageBucket = 'product-images';
  static const blogImageBucket = 'blog-images';
  static const communityBannerBucket = 'community-banners';

  // Pagination
  static const pageSize = 20;
  static const feedPageSize = 15;

  // Wallet
  static const minDeposit = 500; // NGN
  static const minWithdrawal = 1000; // NGN

  // Verification
  static const verificationFee = 2000; // NGN

  // Competition
  static const platformFeePercent = 10;

  // Routes
  static const splashRoute = '/';
  static const onboardingRoute = '/onboarding';
  static const loginRoute = '/login';
  static const registerRoute = '/register';
  static const verifyEmailRoute = '/verify-email';
  static const homeRoute = '/home';
  static const feedRoute = '/feed';
  static const competitionsRoute = '/competitions';
  static const competitionDetailRoute = '/competitions/:id';
  static const communityRoute = '/communities';
  static const communityDetailRoute = '/communities/:id';
  static const subCommunityDetailRoute = '/communities/:id/sub/:subId';
  static const chatRoute = '/chat';
  static const chatDetailRoute = '/chat/:id';
  static const storeRoute = '/store';
  static const productDetailRoute = '/store/product/:id';
  static const walletRoute = '/wallet';
  static const blogRoute = '/blog';
  static const blogDetailRoute = '/blog/:id';
  static const profileRoute = '/profile/:id';
  static const settingsRoute = '/settings';
  static const adminRoute = '/admin';
  static const notificationsRoute = '/notifications';
  static const searchRoute = '/search';
  static const createPostRoute = '/create-post';
}

class UserRole {
  static const user = 'user';
  static const admin = 'admin';
  static const superAdmin = 'super_admin';
  static const moderator = 'moderator';
}

class AdminPermission {
  static const manageUsers = 'manage_users';
  static const manageBlog = 'manage_blog';
  static const manageCompetitions = 'manage_competitions';
  static const manageCommunities = 'manage_communities';
  static const manageStore = 'manage_store';
  static const managePayments = 'manage_payments';
  static const manageAdmins = 'manage_admins';
  static const viewAnalytics = 'view_analytics';
  static const manageVerification = 'manage_verification';
}

class CompetitionStatus {
  static const upcoming = 'upcoming';
  static const live = 'live';
  static const ended = 'ended';
  static const cancelled = 'cancelled';
}

class WalletTransactionType {
  static const deposit = 'deposit';
  static const withdrawal = 'withdrawal';
  static const competitionEntry = 'competition_entry';
  static const competitionWin = 'competition_win';
  static const purchase = 'purchase';
  static const refund = 'refund';
}

class PostType {
  static const text = 'text';
  static const image = 'image';
  static const video = 'video';
  static const clip = 'clip';
}

class VerificationStatus {
  static const unverified = 'unverified';
  static const pending = 'pending';
  static const verified = 'verified';
  static const rejected = 'rejected';
}
