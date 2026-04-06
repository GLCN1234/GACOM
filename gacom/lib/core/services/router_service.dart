import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/main_shell.dart';
import '../../features/feed/screens/feed_screen.dart';
import '../../features/feed/screens/create_post_screen.dart';
import '../../features/competitions/screens/competitions_screen.dart';
import '../../features/competitions/screens/competition_detail_screen.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/community_detail_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.splashRoute,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == AppConstants.loginRoute ||
          state.matchedLocation == AppConstants.registerRoute ||
          state.matchedLocation == AppConstants.onboardingRoute ||
          state.matchedLocation == AppConstants.splashRoute;

      if (!isLoggedIn && !isAuthRoute) {
        return AppConstants.loginRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.splashRoute,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.onboardingRoute,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppConstants.loginRoute,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.registerRoute,
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppConstants.homeRoute,
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: AppConstants.feedRoute,
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: AppConstants.competitionsRoute,
            builder: (context, state) => const CompetitionsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => CompetitionDetailScreen(
                  competitionId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.communityRoute,
            builder: (context, state) => const CommunityScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => CommunityDetailScreen(
                  communityId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.chatRoute,
            builder: (context, state) => const ChatListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => ChatDetailScreen(
                  chatId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.storeRoute,
            builder: (context, state) => const StoreScreen(),
            routes: [
              GoRoute(
                path: 'product/:id',
                builder: (context, state) => ProductDetailScreen(
                  productId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppConstants.walletRoute,
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: AppConstants.blogRoute,
            builder: (context, state) => const BlogScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => BlogDetailScreen(
                  blogId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) => ProfileScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppConstants.settingsRoute,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppConstants.notificationsRoute,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppConstants.searchRoute,
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: AppConstants.createPostRoute,
            builder: (context, state) => const CreatePostScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppConstants.adminRoute,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});
