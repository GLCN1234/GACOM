class AppConstants {
  // Supabase
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Paystack
  static const String paystackPublicKey = 'YOUR_PAYSTACK_PUBLIC_KEY';
  static const String paystackSecretKey = 'YOUR_PAYSTACK_SECRET_KEY';

  // App
  static const String appName = 'GACOM';
  static const String appTagline = 'COMPETE. CONNECT. CONQUER.';
  static const String appVersion = '1.0.0';

  // Routes
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeHome = '/home';
  static const String routeFeed = '/feed';
  static const String routeCompetitions = '/competitions';
  static const String routeCompetitionDetail = '/competitions/:id';
  static const String routeCommunities = '/communities';
  static const String routeCommunityDetail = '/communities/:id';
  static const String routeChat = '/chat';
  static const String routeChatRoom = '/chat/:id';
  static const String routeEcommerce = '/store';
  static const String routeProductDetail = '/store/:id';
  static const String routeProfile = '/profile/:id';
  static const String routeBlog = '/blog';
  static const String routeBlogPost = '/blog/:id';
  static const String routeWallet = '/wallet';
  static const String routeAdmin = '/admin';
  static const String routeVerification = '/verify';

  // Storage Buckets
  static const String bucketAvatars = 'avatars';
  static const String bucketPosts = 'posts';
  static const String bucketProducts = 'products';
  static const String bucketBlog = 'blog';
  static const String bucketCommunities = 'communities';

  // Pagination
  static const int pageSize = 20;
  static const int feedPageSize = 10;
}

class AppStrings {
  static const String noInternetConnection = 'No internet connection';
  static const String somethingWentWrong = 'Something went wrong';
  static const String sessionExpired = 'Session expired. Please log in again.';
}
