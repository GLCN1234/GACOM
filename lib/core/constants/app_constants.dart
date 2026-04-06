class AppConstants {
  static const appName = 'GACOM';
  static const appTagline = 'Game. Connect. Dominate.';
  static const appVersion = '1.0.0';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const paystackPublicKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY', defaultValue: '');
  static const paystackBaseUrl = 'https://api.paystack.co';

  static const avatarBucket = 'avatars';
  static const postMediaBucket = 'post-media';
  static const productImageBucket = 'product-images';
  static const blogImageBucket = 'blog-images';
  static const communityBannerBucket = 'community-banners';

  static const pageSize = 20;
  static const feedPageSize = 15;
  static const minDeposit = 500;
  static const minWithdrawal = 1000;
  static const verificationFee = 2000;
  static const platformFeePercent = 10;

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
