import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/home/screens/main_shell.dart';
import '../../features/feed/screens/feed_screen.dart';
import '../../features/feed/screens/create_post_screen.dart';
import '../../features/feed/screens/reels_screen.dart';
import '../../features/competitions/screens/competitions_screen.dart';
import '../../features/competitions/screens/competition_detail_screen.dart';
import '../../features/competitions/screens/tournament_manager_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/community_detail_screen.dart';
import '../../features/community/screens/gaming_teams_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_detail_screen.dart';
import '../../features/store/screens/store_screen.dart';
import '../../features/store/screens/product_detail_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/blog/screens/blog_screen.dart';
import '../../features/blog/screens/blog_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/home/screens/notifications_screen.dart';
import '../../features/home/screens/search_screen.dart';
import '../../features/ads/screens/ads_screen.dart';
import '../../features/support/screens/support_chat_screen.dart';
import '../../features/support/screens/agent_chat_screen.dart';
import '../../features/exco/screens/exco_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      if (loc == '/reset-password') return null;
      final isAuthRoute = loc == AppConstants.loginRoute ||
          loc == AppConstants.registerRoute ||
          loc == AppConstants.onboardingRoute ||
          loc == AppConstants.splashRoute;
      if (!isLoggedIn && !isAuthRoute) return AppConstants.loginRoute;
      return null;
    },
    routes: [
      GoRoute(path: AppConstants.splashRoute, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppConstants.onboardingRoute, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: AppConstants.loginRoute, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppConstants.registerRoute, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppConstants.homeRoute, builder: (_, __) => const FeedScreen()),
          GoRoute(path: AppConstants.feedRoute, builder: (_, __) => const FeedScreen()),
          GoRoute(
            path: AppConstants.competitionsRoute,
            builder: (_, __) => const CompetitionsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => CompetitionDetailScreen(
                    competitionId: s.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'manage',
                    builder: (_, s) => TournamentManagerScreen(
                      competitionId: s.pathParameters['id']!,
                      isAdmin: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.communityRoute,
            builder: (_, __) => const CommunityScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    CommunityDetailScreen(communityId: s.pathParameters['id']!),
                routes: [
                  // Teams for a specific community — communityId from parent param
                  GoRoute(
                    path: 'teams',
                    builder: (_, s) => GamingTeamsScreen(
                      communityId: s.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.chatRoute,
            builder: (_, __) => const ChatListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    ChatDetailScreen(chatId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.storeRoute,
            builder: (_, __) => const StoreScreen(),
            routes: [
              GoRoute(
                path: 'product/:id',
                builder: (_, s) =>
                    ProductDetailScreen(productId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: AppConstants.walletRoute, builder: (_, __) => const WalletScreen()),
          GoRoute(
            path: AppConstants.blogRoute,
            builder: (_, __) => const BlogScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    BlogDetailScreen(blogId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (_, s) => ProfileScreen(userId: s.pathParameters['id']!),
          ),
          GoRoute(path: AppConstants.settingsRoute, builder: (_, __) => const SettingsScreen()),
          GoRoute(path: AppConstants.notificationsRoute, builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: AppConstants.searchRoute, builder: (_, __) => const SearchScreen()),
          GoRoute(path: AppConstants.createPostRoute, builder: (_, __) => const CreatePostScreen()),
          GoRoute(path: AppConstants.adsRoute, builder: (_, __) => const AdsScreen()),
          GoRoute(path: AppConstants.supportRoute, builder: (_, __) => const SupportChatScreen()),
          GoRoute(path: AppConstants.agentChatRoute, builder: (_, __) => const AgentChatScreen()),
          GoRoute(path: '/reels', builder: (_, __) => const ReelsScreen()),
          // ✅ Exco-only dashboard — NOT the admin dashboard
          GoRoute(path: '/exco-dashboard', builder: (_, __) => const ExcoDashboardScreen()),
        ],
      ),
      GoRoute(path: AppConstants.adminRoute, builder: (_, __) => const AdminDashboardScreen()),
    ],
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      router.go('/reset-password');
    }
  });

  return router;
});
